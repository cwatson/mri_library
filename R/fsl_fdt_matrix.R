#' Recreate fdt_network_matrix from probtrackx2 results
#'
#' This function uses the individual \code{matrix_seeds_to_all_targets} files
#' for each seed region to calculate the total connectivity matrix. It writes a
#' text file called \code{fdt_network_matrix} into the top-level results
#' directory.
#'
#' @param results.dir Character string of the top-level results directory
#' @param P Integer; the number of samples (default: 5000)
#'
#' @author Christopher G. Watson, \email{cgwatson@@bu.edu}
#' @examples
#' \dontrun{
#' fsl_fdt_matrix('~/dti/SP7104/dti2.probtrackX2/results_alt/dk.scgm/')
#' }

fsl_fdt_matrix <- function(results.dir, P=5000) {

  f.s2t <- list.files(list.dirs(results.dir, recursive=T),
                      'matrix_seeds_to_all_targets', full.names=T)
  kNumROI <- length(f.s2t)
  M <- matrix(0, nrow=kNumROI, ncol=kNumROI)
  for (i in seq_along(f.s2t)) {
    Nv <- length(readLines(f.s2t[i]))
    s2t <- matrix(scan(f.s2t[i], what=numeric(0), n=Nv*kNumROI, quiet=T), nrow=Nv,
                  ncol=kNumROI, byrow=T)
    M[i, ] <- colSums(s2t) / (P * Nv)
  }

  # The seeds are not in order, so need to re-order the rows
  seed.order <- apply(M, 1, which.max)
  M2 <- M[, seed.order]
  write.table(M2, col.names=F, row.names=F,
              file=paste0(results.dir, 'fdt_network_matrix'))
}
