using Stipple
using StippleUI
using Genie
using Genie.Requests, Genie.Renderer
using StipplePlotly
using Base.Filesystem

Genie.config.cors_headers["Access-Control-Allow-Origin"] = "*"
Genie.config.cors_headers["Access-Control-Allow-Headers"] = "Content-Type"
Genie.config.cors_headers["Access-Control-Allow-Methods"] = "GET,POST,PUT,DELETE,OPTIONS"
Genie.config.cors_allowed_origins = ["*"]

include("LDLmodel.jl")

# CardDemo definition inheriting from ReactiveModel
# Base.@kwdef: that defines keyword based contructor of mutable struct
@reactive mutable struct Model <: ReactiveModel
  simulate_vectors_pressed::R{Bool} = false
  create_cue_object_pressed::R{Bool} = false
  calc_eos_comp_acc_pressed::R{Bool} = false
  calc_eos_prod_acc_pressed::R{Bool} = false
  calc_prod_alg_acc_pressed::R{Bool} = false
  calc_measures_pressed::R{Bool} = false
  to_code_pressed::R{Bool} = false
  code_download_pressed::R{Bool} = false
  measure_download_pressed::R{Bool} = false
  measures_dialog::R{Bool} = false
  code_dialog::R{Bool} = false

  data::R{String} = ""
  current_data::R{String} = ""
  datasets::R{Vector{String}} = repository_get_available_datasets()

  #current_dataset::R{Union{Missing, DataFrame}} = missing

  ngram::R{Int} = 3
  ncol::R{Int} = 200

  wordform_data::R{DataTable} = DataTable()
  wordform_data_pagination::DataTablePagination = DataTablePagination(rows_per_page=5)
  wordform_data_loading::R{Bool} = false

  S_data::R{DataTable} = DataTable()
  S_data_pagination::DataTablePagination = DataTablePagination(rows_per_page=5)
  S_data_loading::R{Bool} = false
  wordform_col::R{Union{Symbol, String}} = ""
  custom_semvecs::R{Bool} = false
  current_semantic_vectors::R{String} = ""

  cue_data::R{DataTable} = DataTable()
  cue_data_pagination::DataTablePagination = DataTablePagination(rows_per_page=5)
  cue_data_loading::R{Bool} = false

  measures_data::R{DataTable} = DataTable()
  measures_data_pagination::DataTablePagination = DataTablePagination(rows_per_page=5)
  measures_data_loading::R{Bool} = false

  columns::R{Vector{String}} = []
  target_column_selected::R{String} = ""
  base_columns_selected::R{Vector{String}} = []
  inflectional_columns_selected::R{Vector{String}} = []

  comp_acc::R{Float32} = 0.
  comp_acc_loading::R{Bool} = false

  prod_acc::R{Float32} = 0.
  prod_acc_loading::R{Bool} = false

  prod_acc_algo::R{Float32} = 0.
  production_threshold::R{Float32} = 0.1

  code::R{String} = ""

  data_plot::R{PlotData} = pd("Random 1", [], [], Vector{String}())
    layout::R{PlotLayout} = PlotLayout(
        plot_bgcolor = "#333",
        #title = PlotLayoutTitle(text = "Visualize relationships between measures", font = Font(24)),
        xaxis = [PlotLayoutAxis(xy = "x", title_text = "x")],
	    yaxis = [PlotLayoutAxis(xy = "y", title_text = "y")],
    )
  config::R{PlotConfig} = PlotConfig()

  possible_measures::R{Vector{String}} = Vector{String}()
  selected_measure_x::R{String} = ""
  selected_measure_y::R{String} = ""

  cue_number_string::R{String} = ""

  download_link::R{String} = ""
end


function reset_model_objects(model)

    model.target_column_selected[] = ""
    model.base_columns_selected[] = []
    model.inflectional_columns_selected[] = []
    model.cue_data[] = update_visible_data_table()
    model.S_data[] = update_visible_data_table()
    model.ngram[] = 3
    model.measures_data[] = update_visible_data_table()
    model.code[] = ""
    model.wordform_col[] = ""
    model.cue_number_string[] = ""
	model.comp_acc[] = 0.
	model.prod_acc_algo[] = 0.

	reset_public_directory()

    global my_ldl_model = LDLmodel()
end


function load_dataset(model::M; file=missing) where {M<:Stipple.ReactiveModel}
    model.wordform_data[] = update_visible_data_table()
    model.wordform_data_loading[] = true

    reset_model_objects(model)

    model.current_data[] = get_dataset_be(my_ldl_model, file, model.current_data[])

    model.wordform_data[] = update_visible_data_table(data=my_ldl_model.dataset)
    model.columns[] = names(my_ldl_model.dataset)

    model.wordform_data_loading[] = false
end

function update_visible_data_table(;data=missing)
    if ismissing(data)
        DataTable()
    else
        DataTable(data)
    end
end

function load_semantic_vectors(model::M; file=missing) where {M<:Stipple.ReactiveModel}
    model.S_data[] = update_visible_data_table()
    model.S_data_loading[] = true

    model.current_semantic_vectors[], too_big, excluded = set_semantic_vectors_be(my_ldl_model, file,
                                            model.base_columns_selected[],
                                            model.inflectional_columns_selected[],
                                            model.ncol[],
                                            model.current_semantic_vectors[],
                                            model.wordform_col[])
    if too_big
        notify(model, "Not all wordforms could be found in semantic vectors!", :negative, icon = :feedback)
        notify(model, string("Excluded ", excluded, " rows from dataset!"), :negative, icon = :feedback)
    end

    if size(my_ldl_model.dataset, 1) > 3000
        notify(model, "Your dataset is very big, so we are only displaying the first 100 rows and columns here. But don't worry, in the background it's all there!", icon = :feedback)
        temp_S = my_ldl_model.S[1:100, 1:100]
        model.S_data[] = update_visible_data_table(data=DataFrame(temp_S, :auto))
    else
        model.S_data[] = update_visible_data_table(data=DataFrame(my_ldl_model.S, :auto))
    end
    model.S_data_loading[] = false

end


function create_cue_obj(model::M) where {M<:Stipple.ReactiveModel}

    model.cue_data[] = update_visible_data_table()
    model.cue_data_loading[] = true
	print(model.target_column_selected[])
	my_ldl_model.dataset[:, model.target_column_selected[]] = string.(my_ldl_model.dataset[:, model.target_column_selected[]])
	my_ldl_model.dataset[:, model.target_column_selected[]] = convert(Vector{String}, my_ldl_model.dataset[:, model.target_column_selected[]])
    my_ldl_model.cue_obj = JudiLing.make_cue_matrix(my_ldl_model.dataset,
                                                      grams=model.ngram[],
                                                      target_col=model.target_column_selected[])
    if size(my_ldl_model.dataset, 1) > 3000
        notify(model, "Your dataset is very big, so we are only displaying the first 100 rows and columns here. But don't worry, in the background it's all there!", icon = :feedback)
        temp_C = my_ldl_model.cue_obj.C[1:100, 1:100]
        model.cue_data[] = update_visible_data_table(data=DataFrame(temp_C,
                                                              [my_ldl_model.cue_obj.i2f[i] for i in 1:size(temp_C,2)]))
    else
        model.cue_data[] = update_visible_data_table(data=DataFrame(my_ldl_model.cue_obj.C,
                                                          [my_ldl_model.cue_obj.i2f[i] for i in 1:size(my_ldl_model.cue_obj.C,2)]))
    end
    model.cue_number_string[] = get_number_of_cues(my_ldl_model)
    model.cue_data_loading[] = false

end

function calculate_comprehension_accuracy(model::M) where {M<:Stipple.ReactiveModel}
    print(acc_calculable(my_ldl_model))
    if acc_calculable(my_ldl_model)
        model.comp_acc_loading[] = true
        run(model, "notif = this.\$q.notify({
          group: false, // required to be updatable
          timeout: 0, // we want to be in control when it gets dismissed
          spinner: true,
          message: 'Calculating comprehension accuracy...'
        })")
        acc = calculate_comprehension_accuracy_be(my_ldl_model,
                                                  model.target_column_selected[])
        model.comp_acc[] = Float32(acc)
        model.comp_acc_loading[] = false
        run(model, "notif({
              icon: 'done', // we add an icon
              spinner: false, // we reset the spinner setting so the icon can be displayed
              message: 'Done!',
              timeout: 2500 // we will timeout it in 2.5s
            })")
    else
        notify(model, "Please select dataset and semantic vectors and create the cue object first!", :negative, icon = :report_problem)
    end
end


function calculate_production_accuracy(model::M) where {M<:Stipple.ReactiveModel}
    if acc_calculable(my_ldl_model)
        model.prod_acc_loading[] = true
        run(model, "notif = this.\$q.notify({
          group: false, // required to be updatable
          timeout: 0, // we want to be in control when it gets dismissed
          spinner: true,
          message: 'Calculating production accuracy...'
        })")
        acc = calculate_production_accuracy_be(my_ldl_model,
                                               model.target_column_selected[])
        print(acc)
        model.prod_acc[] = Float32(acc)
        model.prod_acc_loading[] = false
        run(model, "notif({
              icon: 'done', // we add an icon
              spinner: false, // we reset the spinner setting so the icon can be displayed
              message: 'Done!',
              timeout: 2500 // we will timeout it in 2.5s
            })")
    else
        notify(model, "Please select dataset and semantic vectors and create the cue object first!", :negative, icon = :report_problem)
    end
end


function update_algo_production_accuracy(model::M) where {M<:Stipple.ReactiveModel}
    if (!ismissing(my_ldl_model.cue_obj) & !ismissing(my_ldl_model.S))
        run(model, "notif = this.\$q.notify({
          group: false, // required to be updatable
          timeout: 0, // we want to be in control when it gets dismissed
          spinner: true,
          message: 'Calculating production algorithm accuracy...',
          caption: 'This may take a while...'
        })")

        acc = calculate_algo_production_accuracy_be(my_ldl_model,
                                                    model.target_column_selected[],
                                                    model.production_threshold[],
                                                    model.ngram[])

        print(acc)
        model.prod_acc_algo[] = Float32(acc)
        run(model, "notif({
              icon: 'done', // we add an icon
              spinner: false, // we reset the spinner setting so the icon can be displayed
              message: 'Done!',
              timeout: 2500 // we will timeout it in 2.5s
            })")
    else
        notify(model, "Please select dataset and semantic vectors and create the cue object first!", :negative, icon = :report_problem)
    end
end


function calculate_measures(model::M) where {M<:Stipple.ReactiveModel}
    if (!ismissing(my_ldl_model.cue_obj) & !ismissing(my_ldl_model.S))
        run(model, "notif = this.\$q.notify({
          group: false, // required to be updatable
          timeout: 0, // we want to be in control when it gets dismissed
          spinner: true,
          message: 'Calculating measures...'
        })")

        model.measures_data[] = update_visible_data_table()
        model.measures_data_loading[] = true
        calculate_measures_be(my_ldl_model)
        model.measures_data[] = update_visible_data_table(data=my_ldl_model.measures)
        model.possible_measures[] = collect(setdiff(Set(names(my_ldl_model.measures)), Set(names(my_ldl_model.dataset))))
        model.selected_measure_x[] = "L1Shat"
        model.selected_measure_y[] = "L2Shat"

        update_measures_plot(model)
        model.measures_data_loading[] = false
        run(model, "notif({
              icon: 'done', // we add an icon
              spinner: false, // we reset the spinner setting so the icon can be displayed
              message: 'Done!',
              timeout: 2500 // we will timeout it in 2.5s
            })")
    else
        notify(my_model, "Please select dataset and semantic vectors and create the cue object first!", :negative, icon = :report_problem)
    end
end

function update_measures_plot(model::M) where {M<:Stipple.ReactiveModel}
    model.data_plot[] = pd("a_name",
                            my_ldl_model.measures[:, model.selected_measure_x[]],
                            my_ldl_model.measures[:, model.selected_measure_y[]],
                            my_ldl_model.measures[:, model.target_column_selected[]])
    model.layout[] = PlotLayout(
        plot_bgcolor = "#333",
        #title = PlotLayoutTitle(text = "Visualize relationships between measures", font = Font(24)),
        xaxis = [PlotLayoutAxis(xy = "x", title_text = model.selected_measure_x[])],
        yaxis = [PlotLayoutAxis(xy = "y", title_text = model.selected_measure_y[])],
    )
end

pd(name, x, y, text) = PlotData(
    x = x,
    y = y,
    plot = StipplePlotly.Charts.PLOT_TYPE_SCATTERGL,
    name = name,
    mode = "markers",
    hovertext = text
)

function ui(my_model)

  [
  "<link rel='preconnect' href='https://fonts.googleapis.com'>"
  "<link rel='preconnect' href='https://fonts.gstatic.com' crossorigin>"
  "<link href='https://fonts.googleapis.com/css2?family=Source+Code+Pro&display=swap' rel='stylesheet'>"
  "<import CSVFile from 'data/latin.csv'>"
    page( # page generates HTML code for Single Page Application
      my_model,
      class = "container",
      title = "LDL GUI",
      partial = true,
      [
        row( # row takes a tuple of cells. Creates a `div` HTML element with a CSS class named `row`.
          h1("Linear Discriminative Learning")
        )
        row([
          cell([
            card(
              class = "st-module",
              style = "background: lightgrey",
              card_section(span("LDL (Linear Discriminative Learning) is a simple model of the mental lexicon,
              modelling comprehension as a mapping from form to meaning, and production as a mapping from meaning to form.
              Further information can be found in <a href='https://benjamins.com/catalog/ml.18010.baa'>Baayen, Chuang and Blevins (2018)</a> and <a href='https://www.hindawi.com/journals/complexity/2019/4895891/'>Baayen, Chuang, Shafaei-Bajestan and Blevins (2019)</a>.")),
            ),
          ]),
          cell([
            card(
              class = "st-module",
              style = "background: lightgrey",
              card_section("This GUI is based on <a href='https://github.com/MegamindHenry/JudiLing.jl'>JudiLing</a> developed by Xuefeng Luo.
			  				Measures are calculated using the <a href='https://github.com/MariaHei/JudiLingMeasures.jl'>JudiLingMeasures</a> package developed by Maria Heitmeier."),
            ),
          ]),
          ]
        )
        row([
          cell(class="st-module", [
            h4("1. Dataset")

            expansionitem(expandseparator=true, label="Use existing dataset", group="dataset", switchtoggleside=true,defaultopened=true,[
            card([
                card_section([Stipple.select(:data, options=:datasets,label="Dataset")])
                ])
            ])
            expansionitem(expandseparator=true, label="Upload custom dataset", group="dataset", switchtoggleside=true,[
            card([
                card_section([uploader(label="Upload custom dataset", :auto__upload, autoupload=true, method="POST", url="http://localhost:8000/upload", field__name="custom_file",accept=".csv", multiple=false),
                 tooltip("Upload your own dataset. This minimmally requires columns for wordform, the word's lexeme/lemma and grammatical features such as tense, number or person. Each wordform should be specified in a new row. For examples see the existing datasets.", maxwidth="200px")
                ])
            ])])
            separator()
            card_section([
            table(:wordform_data;
                  style="height: 400px;",
                  pagination=:wordform_data_pagination,
                  loading=:wordform_data_loading
                  )
                  ])
                 ]
              )

              cell(class="st-module",[
                h4("2. Semantic vectors")

                expansionitem(expandseparator=true, label="Simulate vectors", group="vectors", switchtoggleside=true,defaultopened=true,[

                    card([

                    card_section([
                    Stipple.select(:base_columns_selected, options=:columns, multiple=true, newvaluemode="toggle",clearable=true, label="Select base column(s)", tooltip("Select the column specifying wordforms' lexeme/lemma.", maxwidth="200px"))

                    Stipple.select(:inflectional_columns_selected, options=:columns, multiple=true,newvaluemode="toggle",clearable=true, label="Select inflectional column(s)", tooltip("Select the columns specifying wordforms' grammatical functions such as tense, person or number.", maxwidth="200px"))

                    textfield("Choose dimensionality of semantic vectors", :ncol)
                    ])

                    card_section([btn(:simulate_vectors_pressed, label="Simulate vectors", @click("simulate_vectors_pressed = true"),  color = "red")])

                        ])
                    ])
                    expansionitem(expandseparator=false, label="Upload vectors",group="vectors",switchtoggleside=true, [
                    card([
                    card_section(["Note: Expects wordform names in the first column! Please upload .csv files only.",
                    ])

                    card_section(["Please specify column in dataset with orthographic wordforms to match semantic vectors",
                    Stipple.select(:wordform_col, options=:columns, multiple=false,newvaluemode="toggle",clearable=true, label="Select orthographic wordform column")
                    ]
                    )

                    card_section(
                        uploader(label="Upload custom semantic vectors", :auto__upload, autoupload=true, method="POST", url="http://localhost:8000/upload", field__name="custom_vectors")
                        ) ]
                      )
                      ])
                    separator()

                card_section([
                  table(:S_data;
                        style="height: 200px;",
                        pagination=:S_data_pagination,
                        loading=:S_data_loading
                        )])

              ])

          cell(class="st-module",[
          h4("3. Create cue object")

          card_section([
          Stipple.select(:target_column_selected, options=:columns, multiple=false,clearable=true, label="Select target column")

          textfield("Choose n-gram size", :ngram)
          ])
          card_section([
          row([btn(:create_cue_object_pressed, label="Create cue object", @click("create_cue_object_pressed = true"),  color = "blue")])
          ])
          card_section(
          table(:cue_data;
                style="height: 400px;",
                pagination=:cue_data_pagination,
                loading=:cue_data_loading
                ))

        card_section(span("",@text(:cue_number_string)))
          ])
          ])

          row([
            cell(class="st-module",[
            h4("4. Comprehension")

            row([btn(:calc_eos_comp_acc_pressed, label="Calculate endstate-of-learning accuracy", @click("calc_eos_comp_acc_pressed = true"), color="orange")])

            row([bignumber("Comprehension accuracy (lenient)",
                      :comp_acc,
                      icon="format_list_numbered",
                      color="positive",
                      loading=:comp_acc_loading)])
            ])

            # cell(class="st-module",[
            # h4("5. Production")
            #
            # row([
            # cell([
            #
            # card_section([btn(:calc_eos_prod_acc_pressed, label="Calculate endstate-of-learning accuracy", @click("calc_eos_prod_acc_pressed = true"), color="green")])
            #
            # card_section([bignumber("Production accuracy",
            #           :prod_acc,
            #           icon="format_list_numbered",
            #           color="positive",
            #           loading=:prod_acc_loading)])
            #
            # ])
            #
            # ])
            #
            #
            # ])
            cell(class="st-module",[
            h4("6. Production algorithm")
            card_section(textfield("Choose threshold", :production_threshold))
            card_section([btn(:calc_prod_alg_acc_pressed, label="Calculate production algorithm accuracy", @click("calc_prod_alg_acc_pressed = true"), color="green")])
            card_section([bignumber("Production algorithm accuracy",
                      :prod_acc_algo,
                      icon="format_list_numbered",
                      color="positive")])
            ])
          ])

          row([
          cell(class="st-module",[
          h4("7. Measures")
          card_section(row([card_section(btn(:calc_measures_pressed, label="Calculate measures", @click("calc_measures_pressed = true"), color="green")),
						card_section(btn(:measure_download_pressed, @click("measure_download_pressed = true"), color="grey", icon="file_download"))]))
		  card_section(
          table(:measures_data;
                style="height: 400px;",
                pagination=:measures_data_pagination,
                loading=:measures_data_loading
                ))
		 StippleUI.dialog(:measures_dialog, [
	            card(class = "text-white",
				style="height: 100px; width: 200px",[
 				card_section(h5("Download measures"))
	              card_section(class="q-pt-none", "<a href='measures.csv' download='measures.csv'>Download measures.csv</a>")
	            ])
	          ])
		  card_section("Note: we do not calculate production uncertainty (Saito, 2022), as it is computationally expensive and would result in long waiting times. If you would like to calculate it, use the 'to code' feature and specify `calculate_production_uncertainty=true` inside the compute_all_measures function call.")

		  #card_section([chip(label="<a href='measures.csv' download='measures.csv'>Download measures as .csv</a>")])
		  #btn(:code_download_pressed, label="Download measures", @click("code_download_pressed = true"), color="green")])
		  card_section(
          [
          h5("Visualize relationships between measures")
          Stipple.select(:selected_measure_x, options=:possible_measures, multiple=false, newvaluemode="toggle",clearable=true, label="Select x data")
          Stipple.select(:selected_measure_y, options=:possible_measures, multiple=false, newvaluemode="toggle",clearable=true, label="Select y data")
          plot(:data_plot, layout = :layout, config = :config)])
          ])
          cell(class="st-module",[
          h4("8. To code")
          card_section("You can output your current model as julia code. You can use this feature to further develop your LDL model or make it reproducible.")
          card_section("Note: This feature is currently in beta. Make sure the generated code performs as you expect!")
          card_section(row([card_section(btn(:to_code_pressed, label="Output as code", @click("to_code_pressed = true"), color="green")),
		  				card_section(btn(:code_download_pressed,@click("code_download_pressed = true"), color="grey", icon="file_download"))]))
          card(
            class = "text-white",
            style = "background: black; height: 800px",
            scrollarea(dark=true,card_section(span(style="white-space: pre-wrap; font-family: 'Source Code Pro'", "", @text(:code)))),
          )
		  StippleUI.dialog(:code_dialog, [
 	            card(class = "text-white",
				style="height: 100px; width: 200px",[
 				card_section(h5("Download code"))
 	              card_section(class="q-pt-none", "<a href='code.jl' download='code.jl'>Download code.jl</a>")
 	            ])
 	          ])
          ])
          ])
          #])

        ]
        )
  ]
end

my_model = Stipple.init(Model)
reset_public_directory()
global my_ldl_model = LDLmodel()

on(my_model.data) do _
    my_model.current_data[] = my_model.data[]
    load_dataset(my_model)
end

on(my_model.selected_measure_x) do _
    if my_model.selected_measure_y[] != ""
        update_measures_plot(my_model)
    end
end

on(my_model.selected_measure_y) do _
    if my_model.selected_measure_x[] != ""
        update_measures_plot(my_model)
    end
end


route("/upload", method = POST) do
  if infilespayload(:custom_file)
      f = Genie.Requests.filespayload()
      if !ismissing(:customfile)
          #print(Genie.Requests.filename(filespayload(:custom_file)))
          load_dataset(my_model, file=:custom_file)
      end
  else
    @info "No file uploaded"
  end
  if infilespayload(:custom_vectors)
    if (ismissing(my_ldl_model.dataset) || my_model.wordform_col[] == "")
        notify(my_model, "Please upload dataset first and choose column with orthographic wordforms in dataset!", :negative, icon = :report_problem)
    else
        load_semantic_vectors(my_model, file=:custom_vectors)
    end
  else
    @info "No file uploaded"
  end
end

on(my_model.simulate_vectors_pressed) do _
    if (my_model.simulate_vectors_pressed[] )
        if ((length(my_model.base_columns_selected[])>0) & (length(my_model.inflectional_columns_selected[])>0))
            load_semantic_vectors(my_model)
        else
            notify(my_model, string("Please specify base and inflectional columns"), :negative, icon = :report_problem)
        end
        my_model.simulate_vectors_pressed[] = false
    end
end

on(my_model.create_cue_object_pressed) do _
    if (my_model.create_cue_object_pressed[])
        if ((my_model.target_column_selected[] != ""))
            create_cue_obj(my_model)
        else
            notify(my_model, string("Please specify target column"), :negative, icon = :report_problem)
        end
        my_model.create_cue_object_pressed[] = false
    end
end

on(my_model.calc_eos_comp_acc_pressed) do _
    if (my_model.calc_eos_comp_acc_pressed[])
        calculate_comprehension_accuracy(my_model)
        my_model.calc_eos_comp_acc_pressed[] = false
    end
end

on(my_model.calc_eos_prod_acc_pressed) do _
    if (my_model.calc_eos_prod_acc_pressed[])
        calculate_production_accuracy(my_model)
        my_model.calc_eos_prod_acc_pressed[] = false
    end
end

on(my_model.calc_prod_alg_acc_pressed) do _
    if (my_model.calc_prod_alg_acc_pressed[])
        update_algo_production_accuracy(my_model)
        my_model.calc_prod_alg_acc_pressed[] = false
    end
end

on(my_model.calc_measures_pressed) do _
    if (my_model.calc_measures_pressed[])
        calculate_measures(my_model)
        my_model.calc_measures_pressed[] = false
    end
end

on(my_model.measure_download_pressed) do _
    if (my_model.measure_download_pressed[])
		if (!ismissing(my_ldl_model.measures))
			my_model.measures_dialog[] = true
		end
        my_model.measure_download_pressed[] = false
    end
end

on(my_model.code_download_pressed) do _
    if (my_model.code_download_pressed[])
		if my_model.code[] != ""
			my_model.code_dialog[] = true
		end
        my_model.code_download_pressed[] = false
    end
end

on(my_model.to_code_pressed) do _
    if (my_model.to_code_pressed[])
        if (!ismissing(my_ldl_model.dataset) & !ismissing(my_ldl_model.cue_obj) & !ismissing(my_ldl_model.S))
            run(my_model, "notif = this.\$q.notify({
              group: false, // required to be updatable
              timeout: 0, // we want to be in control when it gets dismissed
              icon: 'code'
              message: 'Generating code. Hang on please...',
              type: 'positive'
            })")
            my_model.code[] = to_code(my_model)
            run(my_model, "notif({
                  icon: 'done', // we add an icon
                  message: 'Done!',
                  timeout: 2500 // we will timeout it in 2.5s
                })")
        else
            notify(my_model, "Please select dataset and semantic vectors and create the cue object first!", :negative, icon = :report_problem)
        end
        my_model.to_code_pressed[] = false
    end
end


route("/") do
   html(ui(my_model), context = @__MODULE__)
end

up(async = true)
