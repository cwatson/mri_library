#' Import a text file containing realignment/movement parameters
#'
#' @param subject_id Character string specifying the subject's Study ID
#' @param session_id Character string specifying the session ID/label (if in a
#'   longitudinal study)
#' @param type Character string specifying either \code{eddy} or \code{spm},
#'   depending on what the movement/realignment parameters were created from
#' @param cutoff Numeric (corresponding to millimeters) specifying the cutoff
#'   value for determining outliers in terms of frame displacement (default:
#'   \code{0.5})
#' @return List containing a \code{data.table} and a "melted" \code{data.table}
#'   with the movement parameters, frame displacement, and outliers
#' @author Christopher G. Watson, \email{cwa135@@alum.mit.edu}

import_rp <- function(subject_id, session_id=NULL, type=c('eddy', 'spm'), cutoff=0.5) {
  type <- match.arg(type)
  if (type == 'spm') {
    work_dir <- '/work/04484/cgwatson/stampede2'
    sub_dir <- paste(work_dir, 'stress_study/fmri', subject_id, 'fmri', sep='/')
    rpfile <- list.files(path=sub_dir, pattern='^rp.*.txt', full.names=TRUE)
  } else {
    sub_dir <- paste0('tractography/sub-', subject_id, '/')
    if (!is.null(session_id)) sub_dir <- paste0(sub_dir, 'ses-', session_id, '/')
    sub_dir <- paste0(sub_dir, 'dwi/eddy/')
    rpfile <- paste0(sub_dir, 'dwi_eddy.eddy_parameters')
  }

  rp <- fread(rpfile)
  rp <- rp[, 1:6, with=FALSE]
  setnames(rp, c('x', 'y', 'z', 'pitch', 'roll', 'yaw'))
  rp[, FD := frame_displacement(rp, cutoff)]
  rp[FD > cutoff, outl := FD]
  rp[, volume := .I]
  rp.m <- melt(rp, id.vars=c('volume', 'outl'))
  rp.m[variable %in% c('x', 'y', 'z'), c('type', 'units') := list('translation', 'mm')]
  rp.m[!variable %in% c('x', 'y', 'z'), c('type', 'units') := list('rotation', 'degrees')]
  rp.m[variable == 'FD', c('type', 'units') := list('FD', 'mm')]
  rp.m[, type := factor(type, levels=c('translation', 'rotation', 'FD'))]

  return(list(DT=rp, DT.m=rp.m))
}

#' Plot realignment parameters and frame displacement
#'
#' Plot the realignment parameters and frame displacement based on estimates
#' from \emph{eddy}.
#'
#' There are 4 plots created:
#' \enumerate{
#'   \item Translations (x-, y-, and z- movement)
#'   \item Rotations (pitch, roll, and yaw)
#'   \item Line plot of \emph{frame displacement}, with the outlier cutoff
#'     represented by a dashed line, and the outliers by a red point
#'   \item Histogram of outliers (based on frame displacement)
#' }
#'
#' @inheritParams import_rp
#' @return A \code{\link[gtable]{gtable}} which contains several
#'   \code{\link[ggplot2]{ggplot}} objects
#' @author Christopher G. Watson, \email{cwa135@@alum.mit.edu}

plot_rp <- function(subject_id, session_id=NULL, type=c('eddy', 'spm'), cutoff=0.5) {
  rp.m <- import_rp(subject_id, session_id, type, cutoff)$DT.m

  plots <- vector('list', 4)
  # Line plot of translational motion (x-, y-, and z-directions)
  plots[[1]] <- ggplot(rp.m[type == 'translation'], aes(x=volume, y=value, col=variable)) +
    geom_line() +
    scale_colour_manual(values=c('blue', 'green', 'red')) +
    theme(plot.title=element_text(hjust=0.5, size=12, face='bold')) +
    labs(title='translation', y='mm')
  # Line plot of rotational motion (pitch, roll, and yaw)
  plots[[2]] <- ggplot(rp.m[type == 'rotation'], aes(x=volume, y=value, col=variable)) +
    geom_line() +
    scale_colour_manual(values=c('blue', 'green', 'red')) +
    theme(plot.title=element_text(hjust=0.5, size=12, face='bold')) +
    labs(title='rotation', y='degrees')

  # Frame displacement plot
  n.outl <- rp.m[variable == 'FD' & outl > 0, .N]
  pct.outl <- round(100 * (n.outl / rp.m[, max(volume)]), 2)
  outl_lab <- paste0('# of outliers: ', n.outl, ' ( / ', rp.m[, max(volume)], ' total volumes)\n', '% outliers: ', pct.outl)
  plots[[3]] <- ggplot(rp.m[type == 'FD'], aes(x=volume, y=value, color=variable)) +
    geom_line() +
    geom_point(aes(y=outl), col='red') +
    geom_hline(yintercept=cutoff, lty=2, col='red') +
    theme(plot.title=element_text(hjust=0.5, size=12, face='bold'),
          plot.caption=element_text(hjust=0.1, size=12, face='bold'),
          legend.position='right') +
    labs(title='Frame Displacement', y='FD (mm)', caption=outl_lab)

  # Histogram of frame displacements
  plots[[4]] <- ggplot(rp.m[type == 'FD'], aes(x=value)) +
    geom_histogram(fill='cyan3', col='black', binwidth=0.05) +
    geom_vline(xintercept=cutoff, lty=2, col='red') +
    labs(x='FD (mm)', y='# of outliers')

  p.all <- arrangeGrob(grobs=plots, nrow=4, top=subject_id)
  return(p.all)
}

#' Convert degrees to radians
#'
#' @param d Numeric; the angle in degrees
#' @return Numeric; the angle in radians
#' @author Christopher G. Watson, \email{cwa135@@alum.mit.edu}

degrees2radians <- function(d) {
  r <- (pi * d) / 180
  return(r)
}

#' Convert degrees to arc lengths (in mm)
#'
#' The first step converts the angle(s) from degrees to radians. The second step
#' converts radians to arc lengths, assuming a sphere radius of 50 mm (see Power
#' et al., NeuroImage, 2012).
#'
#' @param d Numeric; the angle in degrees
#' @param radius Numeric; the radius of a sphere (in mm)
#' @return Numeric; the arc length (in mm)
#' @author Christopher G. Watson, \email{cwa135@@alum.mit.edu}

degrees2length <- function(d, radius=50) {
  r <- degrees2radians(d)
  l <- radius * r
  return(l)
}

#' Calculate framewise displacement
#'
#' The equation for framewise displacement (FD) can be found in Power et al.,
#' NeuroImage, 2012. The \code{cutoff} argument has a default value of 0.5 (in
#' millimeters), which is the cutoff recommended by the authors themselves.
#'
#' @param realign_params A data.table of the realignment parameters with 6
#'   columns corresponding to \code{x}, \code{y}, \code{z}, \code{pitch},
#'   \code{roll}, and \code{yaw}
#' @param cutoff Numeric (corresponding to millimeters) specifying the cutoff
#'   value for determining outliers (default: \code{0.5})
#' @return Numeric vector of the frame displacement for each volume
#' @author Christopher G. Watson, \email{cwa135@@alum.mit.edu}

frame_displacement <- function(realign_params, cutoff=0.5) {
  rp <- copy(realign_params)
  rp[, c('pitch', 'roll', 'yaw') := lapply(.SD, degrees2length), .SDcols=c('pitch', 'roll', 'yaw')]
  diffs <- rp[, lapply(.SD, function(v) abs(-diff(v))), .SDcols=1:6]
  FD <- c(0, diffs[, rowSums(.SD)])
  return(FD)
}

#' Calculate the Percent Artifact Voxels (qi1)
#'
#' @inheritParams import_rp

qi1 <- function(subject_id, session_id=NULL) {
  sub_dir <- paste0('tractography/sub-', subject_id, '/')
  if (!is.null(session_id)) sub_dir <- paste0(sub_dir, 'ses-', session_id, '/')
  sub_dir <- paste0(sub_dir, 'dwi/')

  im <- readNIfTI(paste0(sub_dir, 'nodif_background.nii.gz'))
  x <- im@.Data
  x1 <- x[x > 0]
  n <- length(x1)
  dx <- density(x1)
  xmax <- which.max(dx$y)
  xthresh <- dx$x[xmax]
  n.artifact <- length(x1[x1 > xthresh])
  prop <- n.artifact / n
  return(prop)
}
