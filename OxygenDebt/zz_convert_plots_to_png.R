
# conver all pdf to png ------------------------------------------

pdf2png <- function(fname, dpi = 600) {
  system(sprintf("2png -ag=4 -at=4 -dpi=%i %s", dpi, fname))
}
pdf2png("figures/reliable_model_plots.pdf")

pdf2png("figures/indicator_plots.pdf")


pdfs <- paste0("figures/", dir("figures/", pattern = "*.pdf"))
lapply(pdfs, pdf2png)


system("gswin64c -q -dBATCH -dNOPAUSE -sDEVICE=bbox -dLastPage=1  figures/reliable_model_plots.pdf")

system(sprintf('gswin64c -o figures/out.png -sDEVICE=pngalpha -g%ix%i -dLastPage=1 -c "%i %i translate" -f figures/reliable_model_plots.pdf',
               550-45+1, 673-170+1, 0, 0))

system(sprintf("gswin64c -o figures/out.png -sDEVICE=pngalpha -r720 -g%ix%i -dLastPage=1 -f figures/reliable_model_plots.pdf",
               10*(550-45+1), 10*(673-170+1)))
