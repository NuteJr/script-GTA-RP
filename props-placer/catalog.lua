--[[
    Catalogue des props affichés dans le menu.

    Structure :
        { id = 'identifiant', label = 'Nom affiché', icon = 'emoji', props = { ... } }

    Chaque entrée de `props` est soit une chaîne (le nom du modèle), soit une
    table { model = '...', label = 'Nom lisible' } si vous voulez forcer le
    libellé. Sans libellé, le menu en génère un automatiquement à partir du
    nom du modèle (prop_bench_01a → « Bench 01a »).

    ⚠ Les noms de modèles présents ici sont un point de départ. Au moment
    d'ouvrir le menu, le client VÉRIFIE chaque modèle avec IsModelInCdimage :
    ceux qui n'existent pas dans le jeu du joueur sont simplement masqués
    (Config.UI.HideInvalidModels). Vous pouvez donc ajouter des modèles issus
    de vos ressources streamées sans risque : ils apparaîtront chez les
    joueurs qui les ont, et nulle part ailleurs.
]]

PropCatalog = {

    -- ═════════════════════════════════════════════════════════
    { id = 'urbain', label = 'Mobilier urbain', icon = '🏙️', props = {
        'prop_bench_01a', 'prop_bench_01b', 'prop_bench_01c', 'prop_bench_02',
        'prop_bench_03', 'prop_bench_04', 'prop_bench_05', 'prop_bench_06',
        'prop_bench_07', 'prop_bench_08', 'prop_bench_09', 'prop_bench_10',
        'prop_bench_11',
        'prop_bin_01a', 'prop_bin_02a', 'prop_bin_03a', 'prop_bin_04a',
        'prop_bin_05a', 'prop_bin_06a', 'prop_bin_07a', 'prop_bin_08a',
        'prop_bin_09a', 'prop_bin_10a', 'prop_bin_11a', 'prop_bin_12a',
        'prop_bin_13a', 'prop_bin_14a',
        'prop_postbox_01a',
        'prop_phonebox_01a', 'prop_phonebox_02a', 'prop_phonebox_04a',
        'prop_fire_hydrant_1', 'prop_fire_hydrant_2', 'prop_fire_hydrant_3',
        'prop_parknmeter_01', 'prop_parknmeter_02', 'prop_parkingpay',
        'prop_bikerack_1',
        'prop_busstop_02', 'prop_busstop_04', 'prop_busstop_05',
        'prop_traffic_01a', 'prop_traffic_01b', 'prop_traffic_01d',
        'prop_traffic_02a', 'prop_traffic_03a',
        'prop_sign_road_01a', 'prop_sign_road_03a',
        'prop_fncwood_16a', 'prop_fnclink_03a', 'prop_fnclink_03b',
        'prop_fnclink_05a', 'prop_fnclink_05crnr1',
    }},

    -- ═════════════════════════════════════════════════════════
    { id = 'chantier', label = 'Chantier & signalisation', icon = '🚧', props = {
        'prop_barrier_work01a', 'prop_barrier_work02a', 'prop_barrier_work03',
        'prop_barrier_work04a', 'prop_barrier_work05', 'prop_barrier_work06a',
        'prop_barrier_work06b',
        'prop_mp_barrier_01', 'prop_mp_barrier_02', 'prop_mp_barrier_02b',
        'prop_mp_barrier_03b',
        'prop_roadcone01a', 'prop_roadcone01b', 'prop_roadcone01c',
        'prop_roadcone02a', 'prop_roadcone02b',
        'prop_barier_conc_01a', 'prop_barier_conc_02a', 'prop_barier_conc_03a',
        'prop_barier_conc_04a', 'prop_barier_conc_05a',
        'prop_barrier_wat_03a', 'prop_barrier_wat_04a',
        'prop_worklight_01a', 'prop_worklight_02a', 'prop_worklight_03a',
        'prop_worklight_03b', 'prop_worklight_04a',
        'prop_toolchest_01', 'prop_toolchest_02', 'prop_toolchest_03',
        'prop_toolchest_04', 'prop_toolchest_05',
        'prop_tool_bench02',
        'prop_consign_01a', 'prop_consign_02a', 'prop_consign_03a',
        'prop_ladder_01a',
        'prop_portaloo_01a',
        'prop_generator_03b',
        'prop_flare_01a',
    }},

    -- ═════════════════════════════════════════════════════════
    { id = 'tables', label = 'Tables & chaises', icon = '🪑', props = {
        'prop_table_01', 'prop_table_02', 'prop_table_03', 'prop_table_04',
        'prop_table_05', 'prop_table_06', 'prop_table_07', 'prop_table_08',
        'prop_table_01_chr', 'prop_table_02_chr', 'prop_table_03b_chr',
        'prop_table_04_chr', 'prop_table_05_chr', 'prop_table_06_chr',
        'prop_table_07_chr', 'prop_table_08_chr',
        'prop_chair_01a', 'prop_chair_01b', 'prop_chair_02', 'prop_chair_03',
        'prop_chair_04a', 'prop_chair_04b', 'prop_chair_05', 'prop_chair_06',
        'prop_chair_07', 'prop_chair_08', 'prop_chair_09', 'prop_chair_10',
        'prop_off_chair_01', 'prop_off_chair_02', 'prop_off_chair_03',
        'prop_off_chair_04', 'prop_off_chair_04b', 'prop_off_chair_05',
        'prop_direct_chair_01', 'prop_direct_chair_02',
        'prop_gazebo_01', 'prop_gazebo_02', 'prop_gazebo_03', 'prop_gazebo_04',
        'prop_skid_tent_01', 'prop_skid_tent_03',
        'prop_parasol_01a', 'prop_parasol_02a', 'prop_parasol_03a',
    }},

    -- ═════════════════════════════════════════════════════════
    { id = 'stockage', label = 'Caisses & stockage', icon = '📦', props = {
        'prop_boxpile_01a', 'prop_boxpile_02a', 'prop_boxpile_03a',
        'prop_boxpile_04a', 'prop_boxpile_05a', 'prop_boxpile_06a',
        'prop_boxpile_07a', 'prop_boxpile_07d', 'prop_boxpile_08a',
        'prop_boxpile_09a', 'prop_boxpile_10a',
        'prop_barrel_01a', 'prop_barrel_02a', 'prop_barrel_03a', 'prop_barrel_04a',
        'prop_container_01a', 'prop_container_01mb', 'prop_container_03mb',
        'prop_container_05a',
        'prop_dumpster_01a', 'prop_dumpster_02a', 'prop_dumpster_02b',
        'prop_dumpster_3a', 'prop_dumpster_4a', 'prop_dumpster_4b',
        'prop_cash_case_01', 'prop_cash_crate_01', 'prop_cash_pile_01',
        'prop_cash_pile_02', 'prop_money_bag_01', 'prop_gold_trolly',
        'prop_ld_case_01', 'prop_suitcase_01a', 'prop_suitcase_03',
        'prop_mil_crate_01', 'prop_mil_crate_02',
    }},

    -- ═════════════════════════════════════════════════════════
    { id = 'nourriture', label = 'Nourriture & bar', icon = '🍔', props = {
        'prop_beer_bottle', 'prop_beer_amber', 'prop_beer_logger',
        'prop_beer_pissh', 'prop_beer_stz', 'prop_beer_box', 'prop_beer_neon',
        'prop_drink_champ', 'prop_drink_redwine', 'prop_drink_whisky',
        'prop_cs_beer_bot_01', 'prop_plastic_cup_02', 'prop_ld_flow_bottle',
        'prop_cs_burger_01', 'prop_taco_01', 'prop_sandwich_01', 'prop_food_bag1',
        'prop_bbq_1', 'prop_bbq_2', 'prop_bbq_3', 'prop_bbq_4', 'prop_bbq_5',
        'prop_beach_fire',
        'prop_vend_soda_01', 'prop_vend_soda_02', 'prop_vend_snack_01',
        'prop_vend_water_01', 'prop_vend_coffe_01', 'prop_vend_fags_01',
        'prop_ice_box_01', 'prop_paper_bag_01',
    }},

    -- ═════════════════════════════════════════════════════════
    { id = 'nature', label = 'Nature & plantes', icon = '🌳', props = {
        'prop_tree_birch_01', 'prop_tree_birch_02', 'prop_tree_birch_03',
        'prop_tree_birch_04',
        'prop_tree_maple_02', 'prop_tree_maple_03',
        'prop_tree_cedar_02', 'prop_tree_cedar_03', 'prop_tree_cedar_04',
        'prop_tree_cypress_01', 'prop_tree_eng_oak_01', 'prop_tree_eucalip_01',
        'prop_tree_jacada_01', 'prop_tree_jacada_02', 'prop_tree_oak_01',
        'prop_tree_olive_post', 'prop_tree_pine_01', 'prop_tree_pine_02',
        'prop_tree_fallen_pine_01',
        'prop_bush_lrg_04b', 'prop_bush_med_02',
        'prop_plant_01a', 'prop_plant_02', 'prop_plant_fern_02a',
        'prop_plant_int_01a', 'prop_plant_int_02a', 'prop_plant_int_04a',
        'prop_plant_int_06a',
        'prop_flowerpot_01', 'prop_flowerpot_02', 'prop_flowerpot_03',
        'prop_flowerpot_04', 'prop_flowerpot_05', 'prop_flowerpot_06',
        'prop_flowerpot_07',
        'prop_rock_1_a', 'prop_rock_1_b', 'prop_rock_4_a',
        'prop_veg_grass_01_a', 'prop_veg_crop_03_pump',
    }},

    -- ═════════════════════════════════════════════════════════
    { id = 'eclairage', label = 'Éclairage', icon = '💡', props = {
        'prop_streetlight_01', 'prop_streetlight_01b', 'prop_streetlight_03',
        'prop_streetlight_05', 'prop_streetlight_07a', 'prop_streetlight_08',
        'prop_streetlight_09', 'prop_streetlight_11a', 'prop_streetlight_12a',
        'prop_air_lights_01a', 'prop_air_lights_02a', 'prop_air_lights_03a',
        'prop_air_lights_04a', 'prop_air_lights_05a',
        'prop_studiolight_01', 'prop_studiolight_02', 'prop_studiolight_03',
        'prop_stagelight_02', 'prop_stagelight_04',
        'prop_torch_01', 'prop_torch_02', 'prop_torch_03',
        'prop_candle_01', 'prop_candelabra_01',
        'prop_lights_08a', 'prop_lights_15a',
    }},

    -- ═════════════════════════════════════════════════════════
    { id = 'bureau', label = 'Bureau & électronique', icon = '🖥️', props = {
        'prop_laptop_01a', 'prop_laptop_02_closed', 'prop_laptop_lester',
        'prop_monitor_01a', 'prop_monitor_01b', 'prop_monitor_02',
        'prop_monitor_03', 'prop_keyboard_01a',
        'prop_tv_flat_01', 'prop_tv_flat_02', 'prop_tv_flat_03',
        'prop_tv_flat_michael', 'prop_tv_03',
        'prop_printer_01', 'prop_printer_02',
        'prop_speaker_01', 'prop_speaker_02', 'prop_speaker_05',
        'prop_speaker_07', 'prop_boombox_01',
        'prop_cctv_pole_01', 'prop_cctv_unit_01',
        'prop_paper_box_01', 'prop_paper_ball', 'prop_binder_01',
        'prop_clipboard', 'prop_cs_dumbbell_01',
    }},

    -- ═════════════════════════════════════════════════════════
    { id = 'divers', label = 'Divers', icon = '🔧', props = {
        'prop_tyre_01', 'prop_tyre_02', 'prop_tyre_spike_01',
        'prop_jerrycan_01a', 'prop_gas_pump_1a', 'prop_gas_pump_1b',
        'prop_wheelchair_01', 'prop_shopping_cart_01a',
        'prop_pallet_01a', 'prop_pallet_02a',
        'prop_gascyl_01a', 'prop_gascyl_02a',
        'prop_wooden_pallet_01a', 'prop_woodpile_01a',
        'prop_rub_wheel_01', 'prop_rub_couch01',
        'prop_target_01', 'prop_cs_traffic_cone',
        'prop_sign_road_restrict_01', 'prop_snow_tyre_01',
    }},
}
