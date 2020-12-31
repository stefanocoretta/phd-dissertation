#' Cache the value of an R expression to an RDS file
#'
#' Save the value of an expression to a cache file (of the RDS format). Next
#' time the value is loaded from the file if it exists.
#'
#' @param expr An R expression.
#' @param file The name of the \code{.rds} file in which the object returned by
#'   the expression will be saved (the file hash will be added to the file
#'   name).
#' @param dir The cache directory path (default \code{r_cache/}).
#' @param hash A \code{list} object that contributes to the MD5 hash of the
#'   cache file name.
#' @param clean Whether to clean up the old cache files automatically when
#'   \code{expr} has changed.
#' @param rerun Whether to delete the RDS file, rerun the expression, and save
#'   the result again (i.e., invalidate the cache if it exists).
#' @param ... Other arguments to be passed to \code{\link{saveRDS}()}.
#' @note Changes in the code in the \code{expr} argument do not necessarily
#'   always invalidate the cache, if the changed code is \code{\link{parse}d} to
#'   the same expression as the previous version of the code. For example, if
#'   you have run \code{cache_rds({Sys.sleep(5);1+1})} before, running
#'   \code{cache_rds({ Sys.sleep( 5 ) ; 1 + 1 })} will use the cache, because
#'   the two expressions are essentially the same (they only differ in white
#'   spaces). Usually you can add/delete white spaces or comments to your code
#'   in \code{expr} without invalidating the cache.
#'
#'   Side-effects (such as base r plots or printed output) will not be cached.
#'   The cache only stores the last value of the expression in \code{expr}.
#'   However, ggplot2 plots can be cached, if the output of
#'   \code{link[ggplot2]{ggplot()}} is saved into a variable (you can print the plot
#'   by calling the variable \emph{outside} of \code{\link{cache_rds()}}).
#' @return If the cache file does not exist, run the expression and save the
#'   result to the file, otherwise read the cache file and return the value.
#' @author Yihui Xie
#' @author Stefano Coretta
#' @export
#' @examples
#' f = tempfile()  # the cache file
#' compute = function(...) {
#'   res = xfun::cache_rds({
#'     Sys.sleep(1)
#'     1:10
#'   }, file = f, dir = '', ...)
#'   res
#' }
#' compute()  # takes one second
#' compute()  # returns 1:10 immediately
#' compute()  # fast again
#' compute(rerun = TRUE)  # one second to rerun
#' compute()
#' file.remove(f)
cache_rds <- function(
  expr = {}, file, dir = "r_cache/",
  hash = NULL, clean = TRUE, rerun = FALSE, ...
) {
  path <- paste0(dir, file)
  if (!grepl(r <- '([.]rds)$', path)) path = paste0(path, '.rds')
  code <- deparse(substitute(expr))
  md5  <- md5sum_obj(code)
  if (is.list(hash)) md5 <- md5sum_obj(c(md5, md5sum_obj(hash)))
  path <- sub(r, paste0('_', md5, '\\1'), path)
  if (rerun) unlink(path)
  if (clean) clean_cache(path)
  if (file.exists(path)) readRDS(path) else {
    obj <- expr  # lazy evaluation
    dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
    saveRDS(obj, path, ...)
    obj
  }
}

# write an object to a file and return the md5 sum
md5sum_obj = function(x) {
  f <- tempfile(); on.exit(unlink(f), add = TRUE)
  if (is.character(x)) writeLines(x, f) else saveRDS(x, f)
  tools::md5sum(f)
}

# clean up old cache files (those with the same base names as the new cache
# file, e.g., if the new file is FOO_0123abc...z.rds, then FOO_9876def...x.rds
# should be deleted)
clean_cache = function(path) {
  olds = list.files(dirname(path), '_[0-9a-f]{32}[.]rds$', full.names = TRUE)
  olds = c(olds, path)  # `path` may not exist; make sure it is in target paths
  base = basename(olds)
  keep = basename(path) == base  # keep this file (will cache to this file)
  base = substr(base, 1, nchar(base) - 37)  # 37 = 1 (_) + 32 (md5 sum) + 4 (.rds)
  unlink(olds[(base == base[keep][1]) & !keep])
}

# analyze code and find out global variables
find_globals = function(code) {
  fun = eval(parse_only(c('function(){', code, '}')))
  setdiff(codetools::findGlobals(fun), known_globals)
}

known_globals = c(
  '{', '[', '(', ':', '<-', '=', '+', '-', '*', '/', '%%', '%/%', '%*%', '%o%', '%in%'
)

# return a list of values of global variables in code
global_vars = function(code, env) {
  if (length(vars <- find_globals(code)) > 0) mget(vars, env)
}
