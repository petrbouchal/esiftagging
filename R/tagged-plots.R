make_plot_tagged_all <- function(esif_tagged_sum, tag_var = climate_share, tag_type = "official") {
  data <- esif_tagged_sum %>%
    rename(climate_share = {{tag_var}}) |>
    mutate(climate_share_code = case_when(climate_share == 0 ~ "No tag",
                                          climate_share == 0.4 ~ "Partial (40%)",
                                          climate_share == 1 ~ "Full (100%)",
                                          climate_share == -0.4 ~ "Negative (-40%)",
                                          is.na(climate_share) ~ "Unknown") %>%
             fct_relevel("Full (100%)", "Partial (40%)", "Negative (-40%)", "None", "Unknown") %>% fct_rev()) %>%
    group_by(climate_share_code) %>%
    count(op_zkr, wt = fin_vyuct_czv/1e9) %>%
    ungroup() %>%
    mutate(op_zkr = as_factor(op_zkr) %>% fct_reorder(n, "sum")) %>%
    arrange(op_zkr, desc(climate_share_code)) %>%
    group_by(op_zkr) %>%
    mutate(label_pos = cumsum(n),
           label_value = round(n, 0),
           label_value = if_else(label_value < 1.5, NA_real_, label_value))

  labels_total <- data %>%
    ungroup() %>%
    count(op_zkr, wt = n, name = "total") %>%
    mutate(label_value = round(total, 0))

  ggplot(data, aes(y = op_zkr)) +
    scale_fill_manual(values = c(`Full (100%)` = "darkgreen", `Partial (40%)` = "#009E73",
                                 `Negative (-40%)` = "#E69F00",
                                 `No tag` = "grey30", Unknown = "lightgrey"), name = NULL) +
    geom_col(aes(x = n, fill = climate_share_code)) +
    scale_x_continuous(expand = ptrr::flush_axis) +
    theme_ptrr("x", legend.position = "bottom", legend.key.size = unit(10, "pt")) +
    geom_text(aes(label = label_value, x = label_pos), hjust = 1.5,
              colour = "white", family = "IBM Plex Sans") +
    geom_text(data = labels_total,
              aes(label = label_value, x = total), hjust = 0, nudge_x = 2,
              colour = "grey10", family = "IBM Plex Sans") +
    labs(title = "Spending by climate tags",
         subtitle = str_glue("bn CZK, all spending. Follows {tag_type} climate tags."),
         caption = "Payment data for CZ-PL programme unavailable.")
}

make_plot_weighted_all <- function(esif_tagged_sum, tag_var = climate_share, tag_type = "official") {
  data <- esif_tagged_sum %>%
    rename(climate_share = {{tag_var}}) |>
    count(op_zkr, wt = fin_vyuct_czv * climate_share / 1e9) %>%
    mutate(op_zkr = as_factor(op_zkr) %>% fct_reorder(n))

  ggplot(data, aes(y = op_zkr, x = n)) +
    geom_col(fill = "darkblue") +
    scale_x_continuous(expand = ptrr::flush_axis) +
    theme_ptrr("x", legend.position = "none") +
    geom_text(aes(label = round(n, 0)), hjust = 1.5,
              colour = "white", family = "IBM Plex Sans") +
    labs(title = "Total contribution to climate",
         subtitle = str_glue("bn CZK, all spending weighted by {tag_type} climate tags."),
         caption = "Payment data for CZ-PL programme unavailable.")

}

prep_plot_all_data <- function(esif_tagged_sum, tag_var = climate_share) {
  weighted_contribution <- esif_tagged_sum %>%
    count(wt = fin_vyuct_czv * {{tag_var}} / 1e9) %>%
    pull()

  data <- esif_tagged_sum %>%
    mutate(climate_share_code = case_when({{tag_var}} == 0 ~ "No tag",
                                          {{tag_var}} == 0.4 ~ "Partial (40%)",
                                          {{tag_var}} == 1 ~ "Full (100%)",
                                          {{tag_var}} == -0.4 ~ "Negative (-40%)",
                                          {{tag_var}} == -1 ~ "Negative (-100%)",
                                          is.na({{tag_var}}) ~ "Unknown")) %>%
    filter(climate_share_code != "Unknown") %>%
    count(climate_share_code, wt = fin_vyuct_czv / 1e9) %>%
    add_row(climate_share_code = "Total\nspending",
            n = sum(esif_tagged_sum$fin_vyuct_czv, na.rm = T)/1e9) %>%
    add_row(climate_share_code = "Weighted\ncontribution",
            n = weighted_contribution) %>%
    mutate(climate_share_code = as.factor(climate_share_code) %>%
             fct_relevel("Total\nspending", "No tag", "Full (100%)", "Partial (40%)",
                         "Negative (-40%)", "Negative (-100%)",
                         "Weighted\ncontribution") %>% fct_rev())

  return(data)
}

make_plot_all <- function(plot_all_data, tag_type = "official", agri = TRUE) {

  agri_text = if_else(agri, "Includes relevant CAP spend.", "Excludes CAP spend.")

  ggplot(plot_all_data, aes(n, climate_share_code, fill = climate_share_code)) +
    geom_col() +
    scale_x_continuous(expand = expansion(mult = 0, add = c(0, 50)),
                       n.breaks = 6) +
    scale_fill_manual(values = c(`Full (100%)` = "darkgreen",
                                 `Partial (40%)` = "#009E73",
                                 `Negative (-100%)` = "darkred",
                                 `Negative (-40%)` = "#E69F00",
                                 None = "grey30",
                                 `Total\nspending` = "black",
                                 `Weighted\ncontribution` = "darkblue"),
                      name = NULL, guide = "none") +
    theme_ptrr("x", legend.position = "none") +
    geom_text(aes(label = round(n, 0)), hjust = 0, nudge_x = 10,
              colour = "black", family = "IBM Plex Sans", fontface = "bold") +
    labs(title = "Key figures",
         subtitle = str_glue("bn CZK, using {tag_type} climate tags. {agri_text}"),
         caption = "Payment data for CZ-PL programme unavailable.")
}

make_comparison_plot <- function(plot_all_data, plot_all_data_m) {

  data_linerange <- full_join(plot_all_data,
                              plot_all_data_m |> rename(n2 = n),
                              by = "climate_share_code") |>
    replace_na(list(n = 0)) |>
    filter(climate_share_code != "Total\nspending") |>
    mutate(climate_share_code = as.factor(climate_share_code) %>%
             fct_relevel("Total\nspending", "No tag", "Full (100%)", "Partial (40%)",
                         "Negative (-40%)", "Negative (-100%)",
                         "Weighted\ncontribution") %>% fct_rev() |> fct_drop())

  ggplot(data_linerange, aes(y = climate_share_code)) +
    geom_linerange(aes(xmin = n, xmax = n2),
                   colour = "grey80") +
    geom_point(aes(x = n, colour = "Official"), size = 3) +
    geom_point(aes(x = n2, colour = "Revised"), size = 3) +
    scale_color_manual(values = c("grey30", "lightblue"), name = "Tag source") +
    ptrr::theme_ptrr("x", legend.position = "top") +
    labs(title = "Comparing tags: official vs. CDE revised",
         subtitle = "bn. CZK, total eligible spending by climate tag")

}

make_plot_tagged_agri_detail <- function(agri_tagged) {
  agri_tagged %>%
    count(fond, typ_podpory, opatreni, climate_share, wt = fin_vyuct_czv/1e9) %>%
    mutate(opatreni = as.factor(opatreni) %>% fct_reorder(n, .fun = "sum")) %>%
    ggplot(aes(n, paste0(fond, "\n", typ_podpory), fill = n, group = opatreni)) +
    geom_col() +
    facet_grid(.~climate_share, labeller = label_both) +
    theme_ptrr("x", legend.position = "bottom", multiplot = T)
}

make_plot_tagged_agri <- function(agri_tagged) {
  agri_tagged %>%
    mutate(fond_typ = as_factor(paste0(fond, "\n", typ_podpory)) %>%
             fct_reorder(fin_vyuct_czv, "sum")) %>%
    count(fond_typ, opatreni, climate_share, wt = fin_vyuct_czv/1e9) %>%
    mutate(climate_share_code = case_when(climate_share == 0 ~ "No tag",
                                          climate_share == 0.4 ~ "Partial (40%)",
                                          climate_share == 1 ~ "Full (100%)",
                                          is.na(climate_share) ~ "Unknown") %>%
             fct_relevel("Full (100%)", "Partial (40%)", "No tag", "Unknown") %>% fct_rev()) %>%
    ggplot(aes(n, fond_typ, fill = climate_share_code)) +
    scale_x_continuous(expand = ptrr::flush_axis) +
    scale_fill_manual(values = c(`Full (100%)` = "darkgreen", `Partial (40%)` = "#009E73",
                                 `No tag` = "grey30", Unknown = "lightgrey"), name = NULL) +
    geom_col() +
    theme_ptrr("x", legend.position = "bottom", legend.key.size = unit(10, "pt")) +
    labs(title = "CAP spending by climate tags",
         subtitle = "bn CZK, all spending. Follows official climate tags.")
}

make_plot_retag_decomposition <- function(prj_retagged) {
  prj_retagged |>
    ungroup() |>
    group_by(sc = sc_nazev, oi = oblast_intervence_nazev, op_zkr, retag) |>
    summarise(beg = sum(fin_vyuct_czv * climate_share/1e3),
              end = sum(fin_vyuct_czv * climate_share_m/1e3),
              diff = end - beg, .groups = "drop") |>
    filter(abs(diff) > .1) |>
    mutate(lbl = paste0(op_zkr, ": ", str_trunc(sc, 60), "\n",
                        str_trunc(oi, 60), " (", retag, ")") |>
             fct_reorder(-diff)) |>
    ggplot(aes(y = lbl)) +
    geom_vline(xintercept = 0, linetype = "dotted") +
    geom_linerange(aes(xmin = beg, xmax = end,
                       colour = if_else(diff > 0, "zlepšení", "zhoršení")),
                   key_glyph = draw_key_path,
                   size = 1.5) +
    geom_point(aes(x = beg, fill = "Nařízení"), shape = 21, size = 2, colour = "white") +
    geom_point(aes(x = end, fill = "CDE"), shape = 21, size = 2, colour = "white") +
    scale_colour_manual(values = c(zlepšení = "darkgreen", zhoršení = "darkred"), name = "Dopad reklasifikace") +
    scale_fill_manual(values = c(Nařízení = "darkblue", CDE = "lightblue"), name = "Metodologie") +
    ptrr::theme_ptrr("both", legend.position = "top", base_size = 8, legend.justification = 1, legend.box.just = "left") +
    labs(title = "Příspěvek skupin reklasifikovaných projektů k rozdílu\nmezi klasifikací EK a CDE",
         subtitle = "Zahrnuje pouze kategorie se změnou větší než 100 mil. Kč. Vše v mld. Kč CZV.") +
    guides(fill = guide_legend(order = 1),
           colour = guide_legend(order = 2, keyheight = unit(8, "pt"), keywidth = unit(8, "pt")))

}

make_plot_retag_decomposition_rough <- function(prj_retagged) {
  prj_retagged |>
    ungroup() |>
    group_by(sc = sc_nazev, op_zkr, retag) |>
    summarise(beg = sum(fin_vyuct_czv * climate_share/1e3),
              end = sum(fin_vyuct_czv * climate_share_m/1e3),
              diff = end - beg, .groups = "drop") |>
    filter(abs(diff) > .1) |>
    mutate(lbl = paste0(op_zkr, ": ", str_trunc(sc, 60), " (", retag, ")") |>
             fct_reorder(-diff)) |>
    ggplot(aes(y = lbl)) +
    geom_vline(xintercept = 0, linetype = "dotted") +
    geom_linerange(aes(xmin = beg, xmax = end,
                       colour = if_else(diff > 0, "zlepšení", "zhoršení")),
                   key_glyph = draw_key_path,
                   size = 1.5) +
    geom_point(aes(x = beg, fill = "Nařízení"), shape = 21, size = 2, colour = "white") +
    geom_point(aes(x = end, fill = "CDE"), shape = 21, size = 2, colour = "white") +
    scale_colour_manual(values = c(zlepšení = "darkgreen", zhoršení = "darkred"), name = "Dopad reklasifikace") +
    scale_fill_manual(values = c(Nařízení = "darkblue", CDE = "lightblue"), name = "Metodologie") +
    ptrr::theme_ptrr("both", legend.position = "top", base_size = 8, legend.justification = 1, legend.box.just = "left") +
    labs(title = "Příspěvek skupin reklasifikovaných projektů k rozdílu\nmezi klasifikací EK a CDE",
         subtitle = "Zahrnuje pouze kategorie se změnou větší než 100 mil. Kč. Vše v mld. Kč CZV.") +
    guides(fill = guide_legend(order = 1),
           colour = guide_legend(order = 2, keyheight = unit(8, "pt"), keywidth = unit(8, "pt")))

}
