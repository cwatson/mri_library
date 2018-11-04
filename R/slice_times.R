#' Get slice acquisition times

slice_times <- function(N, TR) {
  timediff <- TR / N
  slicetimes <- (0:(N-1)) * timediff
  slicetimes2 <- rep(0, N)
  slicetimes2[c(seq(1, N, by=2), seq(2, N, by=2))] <- slicetimes
  write.table(slicetimes2, row.names=FALSE, col.names=FALSE, file='slspec.txt')
}
