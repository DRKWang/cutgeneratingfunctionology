from cutgeneratingfunctionology.igp import *
h = kzh_5_slope_fulldim_covers_6()
g = plot_with_colored_slopes(h, show_legend=False, aspect_ratio=0.125, figsize=(8, 1.5), thickness=2, **only_f_ticks_keywords(h))
sphinx_plot(g)