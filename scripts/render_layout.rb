# Render echo_8051 GDS layout to PNG images
app = RBA::Application.instance
mw = app.main_window

RUN = '/work/openlane/echo_8051/runs/RUN_2026.05.10_11.00.16'
GDS = RUN + '/results/final/gds/echo_8051_top.gds'
OUT = '/work/delivery/images'

puts "Loading GDS: #{GDS}"
mw.load_layout(GDS, 0)
lv = mw.current_view
cv = lv.active_cellview
cell = cv.layout.top_cell
lv.select_cell(cv.cell_index, 0)
bbox = cell.bbox
w_um = bbox.width * cv.layout.dbu
h_um = bbox.height * cv.layout.dbu
puts "Cell: #{cell.name}, Size: #{w_um.round}um x #{h_um.round}um = #{(w_um*h_um/1e6).round(3)} mm^2"

# Helper: show only specific layers
def show_layers(lv, gds_layers)
  lv.each_layer do |lp|
    matched = gds_layers.any? { |l, d| lp.source_layer == l && lp.source_datatype == d }
    lp.visible = matched
  end
end

def save(lv, path, label)
  lv.zoom_fit
  lv.save_image(path, 2400, 1800)
  puts "  OK #{label}"
end

# ==== 1. Full chip all layers ====
puts "\n=== Full Chip ==="
lv.zoom_fit
lv.save_image(OUT + '/01_full_chip.png', 2400, 1800)
puts "  OK full_chip"

# ==== 2. Per-layer renders (Sky130 GDS layers) ====
# 67/20=li1, 67/44=licon1, 68/20=met1, 68/44=via1,
# 69/20=met2, 69/44=via2, 70/20=met3, 70/44=via3,
# 71/20=met4, 71/44=via4, 72/20=met5
layers = [
  ['02_li1',    [[67,20]]],
  ['03_licon1', [[67,44]]],
  ['04_met1',   [[68,20]]],
  ['05_via1',   [[68,44]]],
  ['06_met2',   [[69,20]]],
  ['07_via2',   [[69,44]]],
  ['08_met3',   [[70,20]]],
  ['09_via3',   [[70,44]]],
  ['10_met4',   [[71,20]]],
  ['11_via4',   [[71,44]]],
  ['12_met5',   [[72,20]]],
  ['13_met1_to_met3', [[68,20],[68,44],[69,20],[69,44],[70,20]]],
  ['14_met3_to_met5', [[70,20],[70,44],[71,20],[71,44],[72,20]]],
]

layers.each do |name, specs|
  puts "\n=== #{name} ==="
  show_layers(lv, specs)
  save(lv, OUT + "/#{name}.png", name)
end

# ==== 3. Detail zooms ====
puts "\n=== Detail Views ==="
lv.each_layer { |lp| lp.visible = true }
lv.zoom_fit
w = bbox.width
h = bbox.height

# Top-left detail
box = RBA::DBox.new(bbox.left + w*0.0, bbox.bottom + h*0.65,
                    bbox.left + w*0.35, bbox.bottom + h*1.0)
lv.zoom_box(box)
lv.save_image(OUT + '/15_detail_top.png', 2400, 1800)
puts "  OK detail_top"

# Center standard cells
box = RBA::DBox.new(bbox.left + w*0.35, bbox.bottom + h*0.35,
                    bbox.left + w*0.65, bbox.bottom + h*0.65)
lv.zoom_box(box)
lv.save_image(OUT + '/16_detail_center.png', 2400, 1800)
puts "  OK detail_center"

# Transistor-level (li1+licon1+met1)
show_layers(lv, [[67,20],[67,44],[68,20]])
box = RBA::DBox.new(bbox.left + w*0.15, bbox.bottom + h*0.4,
                    bbox.left + w*0.30, bbox.bottom + h*0.6)
lv.zoom_box(box)
lv.save_image(OUT + '/17_detail_transistor.png', 2400, 1800)
puts "  OK detail_transistor"

puts "\n=== All done! ==="
