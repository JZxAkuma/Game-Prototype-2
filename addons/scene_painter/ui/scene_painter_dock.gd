@tool
extends VBoxContainer

# This script builds Scene Painter's bottom panel. It manages the drag-and-drop
# PackedScene palette, inclusion ticks, brush settings, saved configuration, and
# the signals that pass those choices to the editor plugin.
#
# Palette entries remain independent PackedScenes, allowing individual painted
# instances or their shared parent Node3D to be removed from the edited scene.


class ScenePaletteDropArea extends ScrollContainer:
	signal scene_data_dropped(data: Variant)

	func _can_drop_data(_position: Vector2, data: Variant) -> bool:
		if data is Dictionary:
			if data.get("resource") is PackedScene:
				return true

			var files: Variant = data.get("files")
			if files is PackedStringArray or files is Array:
				for file_value in files:
					var path := str(file_value)
					if path.ends_with(".tscn") or path.ends_with(".scn"):
						return true

		return data is PackedScene

	func _drop_data(_position: Vector2, data: Variant) -> void:
		scene_data_dropped.emit(data)


enum HeightOffsetMode {
	WORLD_Y,
	SURFACE_NORMAL,
}


signal selected_scene_changed(scene: PackedScene)
signal scene_palette_changed(scenes: Array)
signal use_selected_parent_changed(enabled: bool)
signal detach_requested

signal brush_enabled_changed(enabled: bool)
signal brush_radius_changed(radius: float)
signal instances_per_click_changed(count: int)
signal minimum_spacing_changed(spacing: float)
signal random_y_rotation_changed(enabled: bool)
signal align_to_surface_changed(enabled: bool)

signal maximum_slope_changed(value: float)

signal random_scale_enabled_changed(enabled: bool)
signal minimum_scale_changed(value: float)
signal maximum_scale_changed(value: float)

signal height_offset_changed(value: float)
signal height_offset_mode_changed(mode: int)


const PALETTE_CONFIG_PATH := "user://scene_painter_palette.cfg"
const LIBRARY_DIRECTORY := "user://.scene_painter_libraries"
const LIBRARY_INDEX_PATH := "user://.scene_painter_libraries/libraries.cfg"
const LIBRARY_INDEX_SECTION := "libraries"
const CONFIG_LIBRARY_NAMES := "names"
const CONFIG_ACTIVE_LIBRARY := "active"

const PALETTE_SECTION := "scene_palette"
const CONFIG_SCENE_PATHS := "scene_paths"
const CONFIG_ACTIVE_SCENE_PATH := "active_scene_path"
const CONFIG_ENABLED_SCENE_PATHS := "enabled_scene_paths"

const SETTINGS_SECTION := "brush_settings"

const SCENE_SETTINGS_SECTION := "scene_brush_settings"
const CONFIG_SCENE_SETTINGS := "profiles"

const CONFIG_BRUSH_RADIUS := "brush_radius"
const CONFIG_INSTANCES_PER_STAMP := "instances_per_stamp"
const CONFIG_MINIMUM_SPACING := "minimum_spacing"

const CONFIG_RANDOM_Y_ROTATION := "random_y_rotation"
const CONFIG_ALIGN_TO_SURFACE := "align_to_surface"
const CONFIG_MAXIMUM_SLOPE := "maximum_slope"

const CONFIG_RANDOM_SCALE_ENABLED := "random_scale_enabled"
const CONFIG_MINIMUM_SCALE := "minimum_scale"
const CONFIG_MAXIMUM_SCALE := "maximum_scale"

const CONFIG_HEIGHT_OFFSET := "height_offset"
const CONFIG_HEIGHT_OFFSET_MODE := "height_offset_mode"
const CONFIG_USE_SELECTED_PARENT := "use_selected_parent"

const INTERFACE_SECTION := "interface"
const CONFIG_INTERFACE_LANGUAGE := "language"

const LANGUAGE_ENGLISH := "en"
const LANGUAGE_ARABIC := "ar"


@onready var title_label: Label = $TitleLabel
@onready var status_label: Label = $StatusLabel


var settings_scroll: ScrollContainer
var controls_container: VBoxContainer
var language_button: Button
var main_layout: HBoxContainer
var palette_panel: VBoxContainer
var library_tabs: TabBar
var add_library_button: Button
var rename_library_button: Button
var delete_library_button: Button
var detach_button: Button
var library_name_dialog: ConfirmationDialog
var library_name_edit: LineEdit
var delete_library_dialog: ConfirmationDialog
var palette_scroll: ScenePaletteDropArea
var scenes_list: HFlowContainer
var palette_title_label: Label
var active_scene_label: Label
var preview_viewport: SubViewport
var preview_camera: Camera3D
var preview_render_in_progress: bool = false
var library_names: Array[String] = []
var active_library_name: String = ""
var library_dialog_mode: String = ""
var is_switching_library: bool = false

var previous_scene_button: Button
var next_scene_button: Button
var use_selected_parent_toggle: CheckButton

var brush_toggle: CheckButton

var brush_radius_label: Label
var radius_spin_box: SpinBox

var instances_label: Label
var instances_spin_box: SpinBox

var spacing_label: Label
var spacing_spin_box: SpinBox

var random_rotation_toggle: CheckButton
var align_surface_toggle: CheckButton

var maximum_slope_label: Label
var maximum_slope_spin_box: SpinBox

var height_offset_label: Label
var height_offset_spin_box: SpinBox

var height_offset_mode_label: Label
var height_offset_mode_option: OptionButton
var height_offset_help_label: Label

var random_scale_toggle: CheckButton

var minimum_scale_label: Label
var minimum_scale_spin_box: SpinBox

var maximum_scale_label: Label
var maximum_scale_spin_box: SpinBox


var scene_rows: Array[Dictionary] = []

var active_picker: EditorResourcePicker
var selected_scene: PackedScene


var brush_enabled: bool = false

var brush_radius: float = 5.0
var instances_per_click: int = 5
var minimum_spacing: float = 1.0

var random_y_rotation: bool = true
var align_to_surface: bool = false

var maximum_slope_degrees: float = 85.0

var height_offset: float = 0.0
var height_offset_mode: int = HeightOffsetMode.SURFACE_NORMAL

var random_scale_enabled: bool = true
var minimum_scale: float = 0.8
var maximum_scale: float = 1.3


var current_language: String = LANGUAGE_ENGLISH
var is_loading_configuration: bool = false
var is_applying_scene_settings: bool = false

var scene_brush_settings: Dictionary = {}

var last_status_source: String = ""
var last_status_display: String = ""
var is_applying_status_translation: bool = false


func _ready() -> void:
	set_process(true)

	_create_interface()
	_load_libraries()

	_apply_language()
	_update_scene_interface()
	_update_controls()

	call_deferred(
		"_emit_loaded_state"
	)
	call_deferred(
		"_render_all_scene_previews"
	)


func _process(
	_delta: float
) -> void:
	_watch_external_status_message()


# -----------------------------------------------------------------------------
# PANEL CONSTRUCTION
# -----------------------------------------------------------------------------

func _create_interface() -> void:
	if is_instance_valid(
		settings_scroll
	):
		return

	main_layout = HBoxContainer.new()
	main_layout.name = "ScenePainterLayout"
	main_layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_insert_before_status(main_layout)

	settings_scroll = ScrollContainer.new()
	settings_scroll.name = "BrushSettingsScroll"

	settings_scroll.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)

	settings_scroll.size_flags_vertical = (
		Control.SIZE_EXPAND_FILL
	)

	settings_scroll.horizontal_scroll_mode = (
		ScrollContainer.SCROLL_MODE_DISABLED
	)

	settings_scroll.vertical_scroll_mode = (
		ScrollContainer.SCROLL_MODE_AUTO
	)

	settings_scroll.follow_focus = true
	settings_scroll.clip_contents = true

	settings_scroll.size_flags_stretch_ratio = 1.0
	settings_scroll.custom_minimum_size = Vector2(260.0, 0.0)
	main_layout.add_child(settings_scroll)

	controls_container = VBoxContainer.new()
	controls_container.name = "BrushControls"

	controls_container.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)

	controls_container.size_flags_vertical = (
		Control.SIZE_SHRINK_BEGIN
	)

	settings_scroll.add_child(
		controls_container
	)

	_create_placement_parent_control()
	_create_brush_toggle()
	_create_radius_control()
	_create_instances_control()
	_create_spacing_control()
	_create_random_rotation_control()
	_create_align_surface_control()
	_create_maximum_slope_control()
	_create_height_offset_controls()
	_create_random_scale_controls()

	palette_panel = VBoxContainer.new()
	palette_panel.name = "ScenePalettePanel"
	palette_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	palette_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	palette_panel.size_flags_stretch_ratio = 2.0
	main_layout.add_child(palette_panel)

	_create_scene_palette()


func _insert_before_status(
	control: Control
) -> void:
	var status_index := status_label.get_index()

	add_child(
		control
	)

	move_child(
		control,
		status_index
	)


# -----------------------------------------------------------------------------
# INTERFACE TEXT
# -----------------------------------------------------------------------------

func _create_language_selector() -> void:
	language_button = Button.new()
	language_button.name = "LanguageButton"

	language_button.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)

	language_button.pressed.connect(
		_on_language_button_pressed
	)

	controls_container.add_child(
		language_button
	)

	var separator := HSeparator.new()
	separator.name = "LanguageSeparator"

	controls_container.add_child(
		separator
	)


func _on_language_button_pressed() -> void:
	if current_language == LANGUAGE_ENGLISH:
		current_language = LANGUAGE_ARABIC
	else:
		current_language = LANGUAGE_ENGLISH

	_apply_language()
	_save_configuration()

	if current_language == LANGUAGE_ARABIC:
		_set_status(
			"Interface language changed to Arabic."
		)
	else:
		_set_status(
			"Interface language changed to English."
		)


func _apply_language() -> void:
	var using_arabic := (
		current_language == LANGUAGE_ARABIC
	)

	if using_arabic:
		layout_direction = (
			Control.LAYOUT_DIRECTION_RTL
		)

		status_label.horizontal_alignment = (
			HORIZONTAL_ALIGNMENT_RIGHT
		)
	else:
		layout_direction = (
			Control.LAYOUT_DIRECTION_LTR
		)

		status_label.horizontal_alignment = (
			HORIZONTAL_ALIGNMENT_LEFT
		)

	if is_instance_valid(title_label):
		title_label.text = _tr(
			"title"
		)

	if is_instance_valid(language_button):
		if using_arabic:
			language_button.text = "English"

			language_button.tooltip_text = (
				"Switch the Scene Painter interface to English."
			)
		else:
			language_button.text = "العربية"

			language_button.tooltip_text = (
				"تغيير واجهة فرشاة العالم إلى العربية."
			)

	if is_instance_valid(palette_title_label):
		palette_title_label.text = _tr(
			"scene_palette"
		)

	if is_instance_valid(previous_scene_button):
		previous_scene_button.text = _tr(
			"previous"
		)

		previous_scene_button.tooltip_text = _tr(
			"previous_tooltip"
		)

	if is_instance_valid(next_scene_button):
		next_scene_button.text = _tr(
			"next"
		)

		next_scene_button.tooltip_text = _tr(
			"next_tooltip"
		)

	if is_instance_valid(brush_toggle):
		brush_toggle.text = _tr(
			"enable_brush"
		)

	if is_instance_valid(brush_radius_label):
		brush_radius_label.text = _tr(
			"brush_radius"
		)

	if is_instance_valid(instances_label):
		instances_label.text = _tr(
			"instances_per_stamp"
		)

	if is_instance_valid(spacing_label):
		spacing_label.text = _tr(
			"minimum_spacing"
		)

	if is_instance_valid(random_rotation_toggle):
		random_rotation_toggle.text = _tr(
			"random_y_rotation"
		)

	if is_instance_valid(align_surface_toggle):
		align_surface_toggle.text = _tr(
			"align_to_surface"
		)

	if is_instance_valid(maximum_slope_label):
		maximum_slope_label.text = _tr(
			"maximum_slope"
		)

	if is_instance_valid(height_offset_label):
		height_offset_label.text = _tr(
			"height_offset"
		)

	if is_instance_valid(height_offset_mode_label):
		height_offset_mode_label.text = _tr(
			"offset_direction"
		)

	if is_instance_valid(height_offset_mode_option):
		height_offset_mode_option.set_item_text(
			HeightOffsetMode.WORLD_Y,
			_tr("world_y")
		)

		height_offset_mode_option.set_item_text(
			HeightOffsetMode.SURFACE_NORMAL,
			_tr("surface_normal")
		)

		height_offset_mode_option.tooltip_text = _tr(
			"offset_mode_tooltip"
		)

		height_offset_mode_option.set_item_tooltip(
			HeightOffsetMode.WORLD_Y,
			_tr("world_y_tooltip")
		)

		height_offset_mode_option.set_item_tooltip(
			HeightOffsetMode.SURFACE_NORMAL,
			_tr("surface_normal_tooltip")
		)

	if is_instance_valid(height_offset_help_label):
		height_offset_help_label.text = _tr(
			"offset_help"
		)

	if is_instance_valid(align_surface_toggle):
		align_surface_toggle.tooltip_text = _tr(
			"align_surface_tooltip"
		)

	if is_instance_valid(random_scale_toggle):
		random_scale_toggle.text = _tr(
			"random_scale"
		)

	if is_instance_valid(minimum_scale_label):
		minimum_scale_label.text = _tr(
			"minimum_scale"
		)

	if is_instance_valid(maximum_scale_label):
		maximum_scale_label.text = _tr(
			"maximum_scale"
		)

	_update_scene_interface()
	_refresh_status_language()


func _tr(
	key: String
) -> String:
	if current_language == LANGUAGE_ARABIC:
		match key:
			"title":
				return "فرشاة العالم"

			"scene_palette":
				return "مكتبة المشاهد"

			"active_scene_none":
				return "المشهد النشط: لا يوجد"

			"previous":
				return "◀ السابق"

			"next":
				return "التالي ▶"

			"previous_tooltip":
				return "اختيار المشهد السابق."

			"next_tooltip":
				return "اختيار المشهد التالي."

			"add_scene":
				return "+ إضافة مشهد"

			"use":
				return "استخدام"

			"active":
				return "نشط"

			"select_scene_tooltip":
				return "جعل هذا المشهد هو المستخدم في الرسم."

			"remove_scene_tooltip":
				return "حذف المشهد من المكتبة."

			"enable_brush":
				return "تفعيل الفرشاة"

			"brush_radius":
				return "حجم الفرشاة"

			"instances_per_stamp":
				return "عدد العناصر في الضربة"

			"minimum_spacing":
				return "أقل مسافة"

			"random_y_rotation":
				return "دوران عشوائي حول Y"

			"align_to_surface":
				return "تدوير المجسم مع السطح"

			"align_surface_tooltip":
				return "يدير المجسم ليتبع ميل السطح. هذا الخيار مستقل عن اتجاه إزاحة الموضع."

			"maximum_slope":
				return "أقصى ميل مسموح"

			"height_offset":
				return "إزاحة الارتفاع"

			"offset_direction":
				return "اتجاه تحريك الموضع"

			"world_y":
				return "على محور Y"

			"surface_normal":
				return "بعيدًا عن السطح"

			"offset_help":
				return "اتجاه الإزاحة يحرك موضع المجسم فقط. لتغيير ميلانه فعّل خيار تدوير المجسم مع السطح."

			"offset_mode_tooltip":
				return "يحدد اتجاه تحريك موضع المجسم، ولا يغير دورانه."

			"world_y_tooltip":
				return "يحرك المجسم للأعلى أو الأسفل على محور Y العالمي."

			"surface_normal_tooltip":
				return "يحرك المجسم بعيدًا عن السطح أو داخله باتجاه Normal السطح."

			"random_scale":
				return "حجم عشوائي"

			"minimum_scale":
				return "أقل حجم"

			"maximum_scale":
				return "أكبر حجم"

			"unsaved_scene":
				return "مشهد غير محفوظ"

			_:
				return key

	match key:
		"title":
			return "Scene Painter"

		"scene_palette":
			return "Scene Palette"

		"active_scene_none":
			return "Active Scene: None"

		"previous":
			return "◀ Previous"

		"next":
			return "Next ▶"

		"previous_tooltip":
			return "Select the previous scene."

		"next_tooltip":
			return "Select the next scene."

		"add_scene":
			return "+ Add Scene"

		"use":
			return "Use"

		"active":
			return "Active"

		"select_scene_tooltip":
			return "Make this the active painting scene."

		"remove_scene_tooltip":
			return "Remove Scene"

		"enable_brush":
			return "Enable Brush"

		"brush_radius":
			return "Brush Radius"

		"instances_per_stamp":
			return "Instances Per Stamp"

		"minimum_spacing":
			return "Minimum Spacing"

		"random_y_rotation":
			return "Random Y Rotation"

		"align_to_surface":
			return "Rotate With Surface"

		"align_surface_tooltip":
			return "Rotates the instance to follow the surface slope. This is independent from the position offset direction."

		"maximum_slope":
			return "Maximum Slope"

		"height_offset":
			return "Height Offset"

		"offset_direction":
			return "Position Offset Direction"

		"world_y":
			return "Along World Y"

		"surface_normal":
			return "Away From Surface"

		"offset_help":
			return "The offset direction moves the instance position only. Enable Rotate With Surface to change its tilt."

		"offset_mode_tooltip":
			return "Controls the direction used to move the instance position. It does not change rotation."

		"world_y_tooltip":
			return "Moves the instance up or down along the global Y axis."

		"surface_normal_tooltip":
			return "Moves the instance away from or into the surface along its normal."

		"random_scale":
			return "Random Scale"

		"minimum_scale":
			return "Minimum Scale"

		"maximum_scale":
			return "Maximum Scale"

		"unsaved_scene":
			return "Unsaved PackedScene"

		_:
			return key


# -----------------------------------------------------------------------------
# STATUS MESSAGES
# -----------------------------------------------------------------------------

func _set_status(
	source_message: String
) -> void:
	last_status_source = source_message

	var translated_message := (
		_translate_status_message(
			source_message
		)
	)

	is_applying_status_translation = true
	status_label.text = translated_message
	is_applying_status_translation = false

	last_status_display = translated_message


func _refresh_status_language() -> void:
	if last_status_source.is_empty():
		last_status_source = status_label.text

	_set_status(
		last_status_source
	)


func _watch_external_status_message() -> void:
	if not is_instance_valid(
		status_label
	):
		return

	if is_applying_status_translation:
		return

	var current_text := status_label.text

	if current_text == last_status_display:
		return

	last_status_source = current_text

	var translated_text := (
		_translate_status_message(
			last_status_source
		)
	)

	is_applying_status_translation = true
	status_label.text = translated_text
	is_applying_status_translation = false

	last_status_display = translated_text


func _translate_status_message(
	message: String
) -> String:
	if current_language != LANGUAGE_ARABIC:
		return message

	var exact_translations := {
		"No Scenes Selected":
			"لم يتم اختيار أي مشهد",

		"New Scene Slot Added":
			"تمت إضافة خانة مشهد جديدة",

		"Choose A Scene In This Slot":
			"اختر مشهدًا في هذه الخانة",

		"At Least One Scene Slot Must Remain":
			"يجب أن تبقى خانة مشهد واحدة على الأقل",

		"Select An Active Scene First":
			"اختر مشهدًا نشطًا أولًا",

		"Brush Disabled":
			"الفرشاة متوقفة",

		"No Valid Surface":
			"لا يوجد سطح صالح",

		"Selected Scene Cannot Be Instantiated":
			"لا يمكن إنشاء نسخة من المشهد المختار",

		"Scene Root Must Be Node3D":
			"يجب أن يكون جذر المشهد من نوع Node3D",

		"3D World Not Available":
			"العالم ثلاثي الأبعاد غير متاح",

		"Edited Scene Changed During Stroke":
			"تم تغيير المشهد أثناء استخدام الفرشاة",

		"Failed To Create Container":
			"تعذر إنشاء حاوية عناصر الفرشاة",

		"No Valid Space Inside Brush":
			"لا توجد مساحة صالحة داخل الفرشاة",

		"Selected Scene Root Must Inherit Node3D":
			"يجب أن يرث جذر المشهد المختار من Node3D",

		"No Scene Painter Instances":
			"لا توجد عناصر منشورة بواسطة الفرشاة",

		"Open A 3D Scene First":
			"افتح مشهدًا ثلاثي الأبعاد أولًا",

		"No Surface Under Cursor":
			"لا يوجد سطح أسفل المؤشر",

		"Invalid Surface Position":
			"موضع السطح غير صالح",

		"Erase Brush — No Instances Here":
			"فرشاة الحذف — لا توجد عناصر هنا",

		"Interface language changed to Arabic.":
			"تم تغيير لغة واجهة الفرشاة إلى العربية.",

		"Interface language changed to English.":
			"تم تغيير لغة واجهة الفرشاة إلى الإنجليزية.",
	}

	if exact_translations.has(
		message
	):
		return str(
			exact_translations[message]
		)

	var prefix_translations := {
		"Active: ":
			"المشهد النشط: ",

		"Brush Enabled — ":
			"الفرشاة مفعّلة — ",

		"Palette Restored: ":
			"تمت استعادة المكتبة: ",

		"Painted In Stroke: ":
			"العناصر المرسومة في السحبة: ",

		"Erased In Stroke: ":
			"العناصر المحذوفة في السحبة: ",

		"Paint Stroke Saved: ":
			"تم حفظ سحبة الرسم: ",

		"Erase Stroke Saved: ":
			"تم حفظ سحبة الحذف: ",
	}

	for english_prefix in prefix_translations:
		if not message.begins_with(
			english_prefix
		):
			continue

		return (
			str(
				prefix_translations[
					english_prefix
				]
			)
			+ message.substr(
				english_prefix.length()
			)
		)

	if message.begins_with(
		"Physics | "
	):
		return (
			"سطح فيزيائي | "
			+ message.substr(
				"Physics | ".length()
			)
		)

	if message.begins_with(
		"Surface | "
	):
		return (
			"سطح | "
			+ message.substr(
				"Surface | ".length()
			)
		)

	return message


# -----------------------------------------------------------------------------
# SCENE PALETTE
# -----------------------------------------------------------------------------

func _create_scene_palette() -> void:
	var assets_heading := Label.new()
	assets_heading.name = "AssetsHeading"
	assets_heading.text = "Assets"
	assets_heading.add_theme_font_size_override("font_size", 16)
	palette_panel.add_child(assets_heading)

	_create_library_controls()

	palette_title_label = Label.new()
	palette_title_label.name = "ScenePaletteTitle"
	palette_title_label.text = "Drag .tscn scenes here"

	palette_panel.add_child(
		palette_title_label
	)

	var separator := HSeparator.new()
	separator.name = "PaletteSeparator"

	palette_panel.add_child(
		separator
	)

	palette_scroll = ScenePaletteDropArea.new()
	palette_scroll.name = "ScenePaletteScroll"
	palette_scroll.tooltip_text = "Drag PackedScene .tscn files here."
	palette_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	palette_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	palette_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	palette_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	palette_scroll.scene_data_dropped.connect(_on_palette_scene_data_dropped)
	palette_panel.add_child(palette_scroll)

	scenes_list = HFlowContainer.new()
	scenes_list.name = "ScenesList"
	scenes_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scenes_list.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	scenes_list.add_theme_constant_override("h_separation", 8)
	scenes_list.add_theme_constant_override("v_separation", 8)
	palette_scroll.add_child(scenes_list)


func _create_library_controls() -> void:
	var library_row := HBoxContainer.new()
	library_row.name = "LibraryControls"
	palette_panel.add_child(library_row)

	library_tabs = TabBar.new()
	library_tabs.name = "LibraryTabs"
	library_tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	library_tabs.tab_changed.connect(_on_library_tab_changed)
	_style_library_tabs()
	library_row.add_child(library_tabs)

	add_library_button = Button.new()
	add_library_button.text = "+"
	add_library_button.tooltip_text = "Create a new Scene Painter library."
	add_library_button.pressed.connect(_on_add_library_pressed)
	library_row.add_child(add_library_button)

	rename_library_button = Button.new()
	rename_library_button.text = "Rename"
	rename_library_button.pressed.connect(_on_rename_library_pressed)
	library_row.add_child(rename_library_button)

	delete_library_button = Button.new()
	delete_library_button.text = "Delete"
	delete_library_button.pressed.connect(_on_delete_library_pressed)
	library_row.add_child(delete_library_button)

	detach_button = Button.new()
	detach_button.text = "Detach"
	detach_button.tooltip_text = "Open Scene Painter in a floating window."
	detach_button.pressed.connect(_on_detach_pressed)
	library_row.add_child(detach_button)

	library_name_dialog = ConfirmationDialog.new()
	library_name_dialog.title = "Scene Painter Library"
	library_name_dialog.confirmed.connect(_on_library_name_confirmed)
	add_child(library_name_dialog)

	library_name_edit = LineEdit.new()
	library_name_edit.placeholder_text = "Library name"
	library_name_edit.custom_minimum_size = Vector2(360.0, 0.0)
	library_name_dialog.add_child(library_name_edit)

	delete_library_dialog = ConfirmationDialog.new()
	delete_library_dialog.title = "Delete Scene Painter Library"
	delete_library_dialog.confirmed.connect(_on_delete_library_confirmed)
	add_child(delete_library_dialog)


func _on_detach_pressed() -> void:
	detach_requested.emit()


func set_detached(detached: bool) -> void:
	if not is_instance_valid(detach_button):
		return
	detach_button.text = "Attach" if detached else "Detach"
	detach_button.tooltip_text = (
		"Return Scene Painter to the bottom dock."
		if detached
		else "Open Scene Painter in a floating window."
	)


func _style_library_tabs() -> void:
	var selected_style := StyleBoxFlat.new()
	selected_style.bg_color = Color("#414141")
	selected_style.border_color = Color("#666666")
	selected_style.border_width_left = 1
	selected_style.border_width_top = 1
	selected_style.border_width_right = 1
	selected_style.corner_radius_top_left = 4
	selected_style.corner_radius_top_right = 4
	selected_style.content_margin_left = 14.0
	selected_style.content_margin_right = 14.0
	selected_style.content_margin_top = 7.0
	selected_style.content_margin_bottom = 7.0

	var unselected_style := selected_style.duplicate() as StyleBoxFlat
	unselected_style.bg_color = Color("#292929")
	unselected_style.border_color = Color("#414141")

	var hover_style := selected_style.duplicate() as StyleBoxFlat
	hover_style.bg_color = Color("#363636")
	hover_style.border_color = Color("#575757")

	var focus_style := StyleBoxEmpty.new()

	library_tabs.add_theme_stylebox_override("tab_selected", selected_style)
	library_tabs.add_theme_stylebox_override("tab_unselected", unselected_style)
	library_tabs.add_theme_stylebox_override("tab_hovered", hover_style)
	library_tabs.add_theme_stylebox_override("tab_focus", focus_style)
	library_tabs.add_theme_color_override("font_selected_color", Color("#f0f0f0"))
	library_tabs.add_theme_color_override("font_unselected_color", Color("#b8b8b8"))
	library_tabs.add_theme_color_override("font_hovered_color", Color.WHITE)
	library_tabs.add_theme_constant_override("h_separation", 3)


func _on_add_library_pressed() -> void:
	library_dialog_mode = "add"
	library_name_edit.text = ""
	library_name_dialog.dialog_text = "Enter a name for the new library."
	library_name_dialog.popup_centered()
	library_name_edit.grab_focus()


func _on_rename_library_pressed() -> void:
	if active_library_name.is_empty():
		return
	library_dialog_mode = "rename"
	library_name_edit.text = active_library_name
	library_name_dialog.dialog_text = "Rename the current library."
	library_name_dialog.popup_centered()
	library_name_edit.grab_focus()
	library_name_edit.select_all()


func _on_delete_library_pressed() -> void:
	if library_names.size() <= 1:
		_set_status("At Least One Library Must Remain")
		return
	delete_library_dialog.dialog_text = (
		"Delete the library \"%s\"?\nThe painted scene instances will not be affected."
		% active_library_name
	)
	delete_library_dialog.popup_centered()


func _on_library_name_confirmed() -> void:
	var requested_name := library_name_edit.text.strip_edges()
	if requested_name.is_empty():
		return

	requested_name = requested_name.validate_filename()
	if requested_name.is_empty():
		return

	if library_dialog_mode == "add":
		_create_library(requested_name)
	elif library_dialog_mode == "rename":
		_rename_active_library(requested_name)


func _on_delete_library_confirmed() -> void:
	if library_names.size() <= 1 or active_library_name.is_empty():
		return

	var old_index := library_names.find(active_library_name)
	var old_path := ProjectSettings.globalize_path(
		_get_library_config_path(active_library_name)
	)
	if FileAccess.file_exists(old_path):
		DirAccess.remove_absolute(old_path)

	library_names.erase(active_library_name)
	active_library_name = library_names[clampi(old_index, 0, library_names.size() - 1)]
	_rebuild_library_tabs()
	_save_library_index()
	_load_active_library()


func _create_library(requested_name: String) -> void:
	var unique_name := _make_unique_library_name(requested_name)
	_save_configuration()
	library_names.append(unique_name)
	active_library_name = unique_name
	_clear_palette_rows()
	scene_brush_settings.clear()
	_rebuild_library_tabs()
	_save_configuration()
	_save_library_index()
	_update_scene_interface()
	_emit_palette_changed()
	_set_status("Library Created: %s" % unique_name)


func _rename_active_library(requested_name: String) -> void:
	if active_library_name.is_empty():
		return

	var unique_name := _make_unique_library_name(requested_name, active_library_name)
	if unique_name == active_library_name:
		return

	_save_configuration()
	var old_name := active_library_name
	var old_path := ProjectSettings.globalize_path(_get_library_config_path(old_name))
	var new_path := ProjectSettings.globalize_path(_get_library_config_path(unique_name))
	if FileAccess.file_exists(old_path):
		DirAccess.rename_absolute(old_path, new_path)

	var library_index := library_names.find(old_name)
	library_names[library_index] = unique_name
	active_library_name = unique_name
	_rebuild_library_tabs()
	_save_library_index()
	_set_status("Library Renamed: %s" % unique_name)


func _on_library_tab_changed(tab_index: int) -> void:
	if is_switching_library or tab_index < 0 or tab_index >= library_names.size():
		return
	var requested_library := library_names[tab_index]
	if requested_library == active_library_name:
		return

	_save_configuration()
	active_library_name = requested_library
	_save_library_index()
	_load_active_library()


func _rebuild_library_tabs() -> void:
	is_switching_library = true
	library_tabs.clear_tabs()
	for library_name in library_names:
		library_tabs.add_tab(library_name)
	library_tabs.current_tab = maxi(library_names.find(active_library_name), 0)
	is_switching_library = false


func _make_unique_library_name(
	requested_name: String,
	ignored_name: String = ""
) -> String:
	var candidate := requested_name
	var suffix := 2
	while library_names.has(candidate) and candidate != ignored_name:
		candidate = "%s %d" % [requested_name, suffix]
		suffix += 1
	return candidate


func _get_library_config_path(library_name: String) -> String:
	return "%s/%s.cfg" % [LIBRARY_DIRECTORY, library_name.validate_filename()]


func _create_placement_parent_control() -> void:
	use_selected_parent_toggle = CheckButton.new()
	use_selected_parent_toggle.name = "UseSelectedParentToggle"
	use_selected_parent_toggle.text = "Paint Under Selected Node3D"
	use_selected_parent_toggle.tooltip_text = (
		"When enabled, painted scenes are added beneath the single Node3D "
		+ "currently selected in the Scene tree."
	)
	use_selected_parent_toggle.toggled.connect(
		_on_use_selected_parent_toggled
	)
	controls_container.add_child(use_selected_parent_toggle)

	var separator := HSeparator.new()
	separator.name = "PlacementParentSeparator"
	controls_container.add_child(separator)


func _on_use_selected_parent_toggled(enabled: bool) -> void:
	use_selected_parent_changed.emit(enabled)


func _create_scene_navigation() -> void:
	var navigation_row := HBoxContainer.new()
	navigation_row.name = "SceneNavigation"

	navigation_row.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)

	previous_scene_button = Button.new()
	previous_scene_button.name = (
		"PreviousSceneButton"
	)

	previous_scene_button.text = "◀ Previous"

	previous_scene_button.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)

	previous_scene_button.pressed.connect(
		_on_previous_scene_pressed
	)

	next_scene_button = Button.new()
	next_scene_button.name = "NextSceneButton"
	next_scene_button.text = "Next ▶"

	next_scene_button.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)

	next_scene_button.pressed.connect(
		_on_next_scene_pressed
	)

	navigation_row.add_child(
		previous_scene_button
	)

	navigation_row.add_child(
		next_scene_button
	)

	controls_container.add_child(
		navigation_row
	)


func _add_scene_row(
	initial_scene: PackedScene = null,
	update_after_creation: bool = true,
	painting_enabled: bool = true
) -> EditorResourcePicker:
	var row := PanelContainer.new()

	row.name = "SceneTile_%d" % (
		scene_rows.size() + 1
	)

	row.custom_minimum_size = Vector2(116.0, 136.0)
	row.tooltip_text = "Right-click to remove this scene."
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	var normal_tile_style := _create_scene_tile_style(false)
	var hover_tile_style := _create_scene_tile_style(true)
	row.add_theme_stylebox_override("panel", normal_tile_style)
	row.mouse_entered.connect(
		_on_scene_tile_mouse_entered.bind(row, hover_tile_style)
	)
	row.mouse_exited.connect(
		_on_scene_tile_mouse_exited.bind(row, normal_tile_style)
	)

	var tile := VBoxContainer.new()
	tile.name = "TileContents"
	row.add_child(tile)

	var picker := EditorResourcePicker.new()
	picker.name = "ScenePicker"
	picker.base_type = "PackedScene"
	picker.editable = true
	picker.visible = false

	var preview_area := Control.new()
	preview_area.name = "PreviewArea"
	preview_area.custom_minimum_size = Vector2(108.0, 104.0)
	preview_area.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var preview := TextureRect.new()
	preview.name = "ScenePreview"
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	preview.texture_repeat = CanvasItem.TEXTURE_REPEAT_DISABLED
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_area.add_child(preview)
	preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	if initial_scene != null:
		picker.edited_resource = initial_scene

	var enabled_toggle := CheckBox.new()
	enabled_toggle.name = "PaintingEnabledToggle"
	enabled_toggle.button_pressed = painting_enabled
	enabled_toggle.tooltip_text = "Include this scene in random painting."
	enabled_toggle.text = ""
	enabled_toggle.position = Vector2(4.0, 4.0)
	enabled_toggle.size = Vector2(28.0, 28.0)
	preview_area.add_child(enabled_toggle)

	var scene_name_label := Label.new()
	scene_name_label.name = "SceneName"
	scene_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	scene_name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	scene_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scene_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	tile.add_child(preview_area)
	tile.add_child(picker)
	tile.add_child(scene_name_label)

	scenes_list.add_child(
		row
	)

	scene_rows.append(
		{
			"row": row,
			"picker": picker,
			"preview": preview,
			"enabled_toggle": enabled_toggle,
			"name_label": scene_name_label,
		}
	)

	picker.resource_changed.connect(
		_on_scene_resource_changed.bind(
			picker
		)
	)

	enabled_toggle.toggled.connect(
		_on_scene_enabled_toggled
	)

	row.gui_input.connect(_on_scene_tile_gui_input.bind(picker))

	if update_after_creation:
		_update_scene_interface()

	_queue_scene_preview(picker)

	return picker


func _create_scene_tile_style(hovered: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#3d3d3d") if not hovered else Color("#484848")
	style.border_color = Color("#666666") if not hovered else Color("#8a8a8a")
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 5.0
	style.content_margin_top = 5.0
	style.content_margin_right = 5.0
	style.content_margin_bottom = 5.0
	return style


func _on_scene_tile_mouse_entered(
	row: PanelContainer,
	hover_style: StyleBoxFlat
) -> void:
	if is_instance_valid(row):
		row.add_theme_stylebox_override("panel", hover_style)


func _on_scene_tile_mouse_exited(
	row: PanelContainer,
	normal_style: StyleBoxFlat
) -> void:
	if is_instance_valid(row):
		row.add_theme_stylebox_override("panel", normal_style)


func _on_scene_tile_gui_input(
	event: InputEvent,
	picker: EditorResourcePicker
) -> void:
	var mouse_event := event as InputEventMouseButton
	if (
		mouse_event != null
		and mouse_event.button_index == MOUSE_BUTTON_RIGHT
		and mouse_event.pressed
	):
		_on_remove_scene_pressed(picker)
		accept_event()


func _on_scene_enabled_toggled(_enabled: bool) -> void:
	_update_scene_interface()
	_emit_palette_changed()
	_disable_brush_if_no_scene()
	_save_configuration()


func _on_palette_scene_data_dropped(data: Variant) -> void:
	var dropped_scenes: Array[PackedScene] = []

	if data is PackedScene:
		dropped_scenes.append(data as PackedScene)
	elif data is Dictionary:
		var resource: Variant = data.get("resource")
		if resource is PackedScene:
			dropped_scenes.append(resource as PackedScene)

		var files: Variant = data.get("files")
		if files is PackedStringArray or files is Array:
			for file_value in files:
				var path := str(file_value)
				if not ResourceLoader.exists(path, "PackedScene"):
					continue
				var loaded_scene := ResourceLoader.load(path, "PackedScene") as PackedScene
				if loaded_scene != null:
					dropped_scenes.append(loaded_scene)

	if dropped_scenes.is_empty():
		_set_status("Drop PackedScene .tscn Files Here")
		return

	for scene in dropped_scenes:
		if _palette_contains_scene(scene):
			continue
		_add_scene_row(scene, false, true)

	_remove_empty_scene_rows()
	_select_first_available_scene()
	_update_scene_interface()
	_emit_palette_changed()
	_emit_active_scene_changed()
	_save_configuration()
	_set_status("Added %d Scene(s)" % dropped_scenes.size())
	call_deferred("_render_all_scene_previews")


func _palette_contains_scene(scene: PackedScene) -> bool:
	for entry in scene_rows:
		var picker := _get_picker_from_row(entry)
		if picker.edited_resource == scene:
			return true
		if (
			picker.edited_resource is PackedScene
			and not scene.resource_path.is_empty()
			and picker.edited_resource.resource_path == scene.resource_path
		):
			return true
	return false


func _remove_empty_scene_rows() -> void:
	for index in range(scene_rows.size() - 1, -1, -1):
		var entry: Dictionary = scene_rows[index]
		var picker := _get_picker_from_row(entry)
		if _picker_has_scene(picker):
			continue
		var row := entry.get("row") as Control
		scene_rows.remove_at(index)
		if is_instance_valid(row):
			row.queue_free()


func _on_scene_resource_changed(
	resource: Resource,
	picker: EditorResourcePicker
) -> void:
	var packed_scene := (
		resource as PackedScene
	)

	var picker_was_active := (
		picker == active_picker
	)

	if picker_was_active:
		_store_current_scene_settings()

	if (
		packed_scene != null
		and not is_instance_valid(
			active_picker
		)
	):
		active_picker = picker
		selected_scene = packed_scene

	elif picker_was_active:
		if packed_scene == null:
			active_picker = null
			selected_scene = null

			_select_first_available_scene()
		else:
			selected_scene = packed_scene

	if (
		picker == active_picker
		and selected_scene != null
	):
		_load_active_scene_settings(
			false
		)

	_update_scene_interface()
	_queue_scene_preview(picker)
	_emit_palette_changed()
	_emit_active_scene_changed()
	_emit_all_brush_settings_changed()
	_save_configuration()


func _queue_scene_preview(picker: EditorResourcePicker) -> void:
	var preview_control: TextureRect = null
	for entry in scene_rows:
		if _get_picker_from_row(entry) == picker:
			preview_control = entry.get("preview") as TextureRect
			break

	if not is_instance_valid(preview_control):
		return

	var packed_scene := picker.edited_resource as PackedScene
	if packed_scene == null or packed_scene.resource_path.is_empty():
		preview_control.texture = get_theme_icon("PackedScene", "EditorIcons")
		return

	EditorInterface.get_resource_previewer().queue_resource_preview(
		packed_scene.resource_path,
		self,
		&"_on_scene_preview_ready",
		preview_control
	)


func _refresh_scene_previews() -> void:
	for entry in scene_rows:
		_queue_scene_preview(_get_picker_from_row(entry))


func _render_all_scene_previews() -> void:
	if preview_render_in_progress:
		return

	preview_render_in_progress = true
	_ensure_preview_viewport()

	for entry in scene_rows:
		var picker := _get_picker_from_row(entry)
		var preview_control := entry.get("preview") as TextureRect
		var packed_scene := picker.edited_resource as PackedScene
		if packed_scene == null or not is_instance_valid(preview_control):
			continue

		var rendered_texture := await _render_scene_preview(packed_scene)
		if rendered_texture != null and is_instance_valid(preview_control):
			preview_control.texture = rendered_texture

	preview_render_in_progress = false


func _ensure_preview_viewport() -> void:
	if is_instance_valid(preview_viewport):
		return

	preview_viewport = SubViewport.new()
	preview_viewport.name = "ScenePreviewViewport"
	preview_viewport.size = Vector2i(256, 256)
	preview_viewport.transparent_bg = true
	preview_viewport.own_world_3d = true
	preview_viewport.world_3d = World3D.new()
	preview_viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	preview_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(preview_viewport)

	preview_camera = Camera3D.new()
	preview_camera.current = true
	preview_camera.fov = 35.0
	preview_viewport.add_child(preview_camera)

	var key_light := DirectionalLight3D.new()
	key_light.light_energy = 1.0
	key_light.rotation_degrees = Vector3(-50.0, -35.0, 0.0)
	preview_viewport.add_child(key_light)

	var fill_light := DirectionalLight3D.new()
	fill_light.light_energy = 0.45
	fill_light.rotation_degrees = Vector3(-25.0, 145.0, 0.0)
	preview_viewport.add_child(fill_light)


func _render_scene_preview(packed_scene: PackedScene) -> Texture2D:
	if not packed_scene.can_instantiate():
		return null

	var preview_instance := packed_scene.instantiate()
	if not preview_instance is Node3D:
		preview_instance.free()
		return null

	preview_viewport.add_child(preview_instance)
	await get_tree().process_frame

	var bounds_data := {
		"found": false,
		"bounds": AABB(),
	}
	_collect_preview_bounds(preview_instance, bounds_data)

	if not bool(bounds_data["found"]):
		preview_instance.queue_free()
		await get_tree().process_frame
		return null

	var bounds: AABB = bounds_data["bounds"]
	var centre := bounds.get_center()
	var largest_size := maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z))
	var camera_distance := maxf(largest_size * 2.2, 1.0)
	var camera_direction := Vector3(1.0, 0.65, 1.0).normalized()

	preview_camera.position = centre + camera_direction * camera_distance
	preview_camera.near = maxf(camera_distance * 0.001, 0.01)
	preview_camera.far = maxf(camera_distance * 4.0, 100.0)
	preview_camera.look_at(centre, Vector3.UP)

	preview_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw

	var preview_image := preview_viewport.get_texture().get_image()
	var rendered_texture: Texture2D = null
	if preview_image != null and not preview_image.is_empty():
		rendered_texture = ImageTexture.create_from_image(preview_image)

	preview_instance.queue_free()
	await get_tree().process_frame
	return rendered_texture


func _collect_preview_bounds(node: Node, bounds_data: Dictionary) -> void:
	if node is MeshInstance3D and node.mesh != null:
		var mesh_instance := node as MeshInstance3D
		var mesh_bounds := mesh_instance.global_transform * mesh_instance.get_aabb()
		if bool(bounds_data["found"]):
			bounds_data["bounds"] = (bounds_data["bounds"] as AABB).merge(mesh_bounds)
		else:
			bounds_data["bounds"] = mesh_bounds
			bounds_data["found"] = true

	for child in node.get_children():
		_collect_preview_bounds(child, bounds_data)


func _on_scene_preview_ready(
	_path: String,
	preview_texture: Texture2D,
	thumbnail_texture: Texture2D,
	userdata: Variant
) -> void:
	var preview_control := userdata as TextureRect
	if not is_instance_valid(preview_control):
		return

	if preview_texture != null:
		preview_control.texture = preview_texture
	elif thumbnail_texture != null:
		preview_control.texture = thumbnail_texture
	else:
		preview_control.texture = get_theme_icon("PackedScene", "EditorIcons")


func _on_select_scene_pressed(
	picker: EditorResourcePicker
) -> void:
	if not is_instance_valid(
		picker
	):
		return

	var packed_scene := (
		picker.edited_resource
		as PackedScene
	)

	if packed_scene == null:
		_set_status(
			"Choose A Scene In This Slot"
		)

		return

	_set_active_picker(
		picker
	)


func _on_remove_scene_pressed(
	picker: EditorResourcePicker
) -> void:
	var row_to_remove: Control = null
	var index_to_remove: int = -1

	var removed_active_scene := (
		picker == active_picker
	)

	if removed_active_scene:
		_store_current_scene_settings()

	for index in range(
		scene_rows.size()
	):
		var entry_picker := (
			scene_rows[index].get(
				"picker"
			)
			as EditorResourcePicker
		)

		if entry_picker != picker:
			continue

		row_to_remove = (
			scene_rows[index].get(
				"row"
			)
			as Control
		)

		index_to_remove = index
		break

	if index_to_remove < 0:
		return

	scene_rows.remove_at(
		index_to_remove
	)

	if removed_active_scene:
		active_picker = null
		selected_scene = null

	if is_instance_valid(
		row_to_remove
	):
		row_to_remove.queue_free()

	if removed_active_scene:
		_select_available_scene_near_index(
			index_to_remove
		)

		_load_active_scene_settings(
			false
		)

	_update_scene_interface()
	_emit_palette_changed()
	_disable_brush_if_no_scene()
	_save_configuration()
	_emit_active_scene_changed()

	if removed_active_scene:
		_emit_all_brush_settings_changed()

	_save_configuration()


func _on_previous_scene_pressed() -> void:
	_change_active_scene(
		-1
	)


func _on_next_scene_pressed() -> void:
	_change_active_scene(
		1
	)


func _change_active_scene(
	direction: int
) -> void:
	var valid_pickers := (
		_get_valid_scene_pickers()
	)

	if valid_pickers.is_empty():
		active_picker = null
		selected_scene = null

		_update_scene_interface()
		_emit_active_scene_changed()
		_save_configuration()

		return

	var current_index := valid_pickers.find(
		active_picker
	)

	if current_index < 0:
		current_index = 0
	else:
		current_index = posmod(
			current_index + direction,
			valid_pickers.size()
		)

	_set_active_picker(
		valid_pickers[current_index]
	)


func _set_active_picker(
	picker: EditorResourcePicker
) -> void:
	if not is_instance_valid(
		picker
	):
		return

	var packed_scene := (
		picker.edited_resource
		as PackedScene
	)

	if packed_scene == null:
		return

	_store_current_scene_settings()

	active_picker = picker
	selected_scene = packed_scene

	_load_active_scene_settings(
		false
	)

	_update_scene_interface()
	_emit_active_scene_changed()
	_emit_all_brush_settings_changed()
	_save_configuration()

	_set_status(
		"Active: %s"
		% _get_scene_display_name(
			selected_scene
		)
	)


func _select_first_available_scene() -> void:
	var valid_pickers := (
		_get_valid_scene_pickers()
	)

	if valid_pickers.is_empty():
		active_picker = null
		selected_scene = null

		return

	active_picker = valid_pickers[0]

	selected_scene = (
		active_picker.edited_resource
		as PackedScene
	)


func _select_available_scene_near_index(
	preferred_index: int
) -> void:
	if scene_rows.is_empty():
		active_picker = null
		selected_scene = null

		return

	var clamped_index := clampi(
		preferred_index,
		0,
		scene_rows.size() - 1
	)

	for index in range(
		clamped_index,
		scene_rows.size()
	):
		var picker := _get_picker_from_row(
			scene_rows[index]
		)

		if not _picker_has_scene(
			picker
		):
			continue

		active_picker = picker

		selected_scene = (
			picker.edited_resource
			as PackedScene
		)

		return

	for index in range(
		clamped_index - 1,
		-1,
		-1
	):
		var picker := _get_picker_from_row(
			scene_rows[index]
		)

		if not _picker_has_scene(
			picker
		):
			continue

		active_picker = picker

		selected_scene = (
			picker.edited_resource
			as PackedScene
		)

		return

	active_picker = null
	selected_scene = null


# -----------------------------------------------------------------------------
# CONFIGURATION STORAGE
# -----------------------------------------------------------------------------

func _save_configuration() -> void:
	if is_loading_configuration:
		return

	_store_current_scene_settings()

	var scene_paths := PackedStringArray()
	var enabled_scene_paths := PackedStringArray()

	for entry in scene_rows:
		var picker := _get_picker_from_row(entry)
		if not _picker_has_scene(picker):
			continue
		var packed_scene := (
			picker.edited_resource
			as PackedScene
		)

		if packed_scene == null:
			continue

		if packed_scene.resource_path.is_empty():
			continue

		scene_paths.append(
			packed_scene.resource_path
		)

		var enabled_toggle := entry.get("enabled_toggle") as CheckBox
		if is_instance_valid(enabled_toggle) and enabled_toggle.button_pressed:
			enabled_scene_paths.append(packed_scene.resource_path)

	var active_scene_path := ""

	if is_instance_valid(
		active_picker
	):
		var active_scene := (
			active_picker.edited_resource
			as PackedScene
		)

		if active_scene != null:
			active_scene_path = (
				active_scene.resource_path
			)

	var config := ConfigFile.new()

	config.set_value(
		PALETTE_SECTION,
		CONFIG_SCENE_PATHS,
		scene_paths
	)

	config.set_value(
		PALETTE_SECTION,
		CONFIG_ACTIVE_SCENE_PATH,
		active_scene_path
	)

	config.set_value(
		PALETTE_SECTION,
		CONFIG_ENABLED_SCENE_PATHS,
		enabled_scene_paths
	)

	config.set_value(
		SETTINGS_SECTION,
		CONFIG_BRUSH_RADIUS,
		brush_radius
	)

	config.set_value(
		SETTINGS_SECTION,
		CONFIG_INSTANCES_PER_STAMP,
		instances_per_click
	)

	config.set_value(
		SETTINGS_SECTION,
		CONFIG_MINIMUM_SPACING,
		minimum_spacing
	)

	config.set_value(
		SETTINGS_SECTION,
		CONFIG_RANDOM_Y_ROTATION,
		random_y_rotation
	)

	config.set_value(
		SETTINGS_SECTION,
		CONFIG_ALIGN_TO_SURFACE,
		align_to_surface
	)

	config.set_value(
		SETTINGS_SECTION,
		CONFIG_MAXIMUM_SLOPE,
		maximum_slope_degrees
	)

	config.set_value(
		SETTINGS_SECTION,
		CONFIG_HEIGHT_OFFSET,
		height_offset
	)

	config.set_value(
		SETTINGS_SECTION,
		CONFIG_HEIGHT_OFFSET_MODE,
		height_offset_mode
	)

	config.set_value(
		SETTINGS_SECTION,
		CONFIG_RANDOM_SCALE_ENABLED,
		random_scale_enabled
	)

	config.set_value(
		SETTINGS_SECTION,
		CONFIG_MINIMUM_SCALE,
		minimum_scale
	)

	config.set_value(
		SETTINGS_SECTION,
		CONFIG_MAXIMUM_SCALE,
		maximum_scale
	)

	config.set_value(
		SETTINGS_SECTION,
		CONFIG_USE_SELECTED_PARENT,
		use_selected_parent_toggle.button_pressed
	)

	config.set_value(
		INTERFACE_SECTION,
		CONFIG_INTERFACE_LANGUAGE,
		current_language
	)

	config.set_value(
		SCENE_SETTINGS_SECTION,
		CONFIG_SCENE_SETTINGS,
		scene_brush_settings
	)

	var save_path := (
		_get_library_config_path(active_library_name)
		if not active_library_name.is_empty()
		else PALETTE_CONFIG_PATH
	)
	var save_error := config.save(save_path)

	if save_error != OK:
		push_warning(
			"Scene Painter: Failed to save configuration. Error: %s"
			% error_string(save_error)
		)


func _load_libraries() -> void:
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(LIBRARY_DIRECTORY)
	)

	var index_config := ConfigFile.new()
	if index_config.load(LIBRARY_INDEX_PATH) == OK:
		var stored_names: Variant = index_config.get_value(
			LIBRARY_INDEX_SECTION,
			CONFIG_LIBRARY_NAMES,
			PackedStringArray()
		)
		if stored_names is PackedStringArray or stored_names is Array:
			for name_value in stored_names:
				var library_name := str(name_value)
				if not library_name.is_empty():
					library_names.append(library_name)

		active_library_name = str(
			index_config.get_value(
				LIBRARY_INDEX_SECTION,
				CONFIG_ACTIVE_LIBRARY,
				""
			)
		)

	if library_names.is_empty():
		library_names.append("Default")
		active_library_name = "Default"
		_rebuild_library_tabs()

		if FileAccess.file_exists(PALETTE_CONFIG_PATH):
			_load_configuration_from_path(PALETTE_CONFIG_PATH)
			_save_configuration()
		else:
			_save_configuration()
		_save_library_index()
		return

	if not library_names.has(active_library_name):
		active_library_name = library_names[0]

	_rebuild_library_tabs()
	_load_active_library()


func _save_library_index() -> void:
	var index_config := ConfigFile.new()
	index_config.set_value(
		LIBRARY_INDEX_SECTION,
		CONFIG_LIBRARY_NAMES,
		PackedStringArray(library_names)
	)
	index_config.set_value(
		LIBRARY_INDEX_SECTION,
		CONFIG_ACTIVE_LIBRARY,
		active_library_name
	)
	var save_error := index_config.save(LIBRARY_INDEX_PATH)
	if save_error != OK:
		push_warning(
			"Scene Painter: Failed to save library index. Error: %s"
			% error_string(save_error)
		)


func _load_active_library() -> void:
	_clear_palette_rows()
	scene_brush_settings.clear()
	_load_configuration_from_path(
		_get_library_config_path(active_library_name)
	)
	_apply_language()
	_update_scene_interface()
	_apply_settings_to_controls()
	_emit_palette_changed()
	_emit_active_scene_changed()
	_emit_all_brush_settings_changed()
	call_deferred("_render_all_scene_previews")
	_set_status("Library: %s" % active_library_name)


func _clear_palette_rows() -> void:
	for entry in scene_rows:
		var row := entry.get("row") as Control
		if is_instance_valid(row):
			row.queue_free()
	scene_rows.clear()
	active_picker = null
	selected_scene = null


func _load_configuration_from_path(config_path: String) -> void:
	is_loading_configuration = true

	var config := ConfigFile.new()

	var load_error := config.load(
		config_path
	)

	if load_error != OK:
		is_loading_configuration = false
		return

	_load_interface_settings(
		config
	)

	_load_brush_settings(
		config
	)

	_load_scene_brush_settings(
		config
	)

	var stored_paths: Variant = config.get_value(
		PALETTE_SECTION,
		CONFIG_SCENE_PATHS,
		PackedStringArray()
	)

	var active_scene_path := str(
		config.get_value(
			PALETTE_SECTION,
			CONFIG_ACTIVE_SCENE_PATH,
			""
		)
	)

	var stored_enabled_paths: Variant = config.get_value(
		PALETTE_SECTION,
		CONFIG_ENABLED_SCENE_PATHS,
		stored_paths
	)
	var enabled_scene_paths: Array[String] = []
	if typeof(stored_enabled_paths) == TYPE_PACKED_STRING_ARRAY or typeof(stored_enabled_paths) == TYPE_ARRAY:
		for path_value in stored_enabled_paths:
			enabled_scene_paths.append(str(path_value))

	var scene_paths: Array[String] = []

	if typeof(
		stored_paths
	) == TYPE_PACKED_STRING_ARRAY:
		for path_value in stored_paths:
			scene_paths.append(
				str(path_value)
			)

	elif typeof(
		stored_paths
	) == TYPE_ARRAY:
		for path_value in stored_paths:
			scene_paths.append(
				str(path_value)
			)

	for scene_path in scene_paths:
		if scene_path.is_empty():
			continue

		if not ResourceLoader.exists(
			scene_path,
			"PackedScene"
		):
			push_warning(
				"Scene Painter: Saved scene no longer exists -> %s"
				% scene_path
			)

			continue

		var loaded_scene := (
			ResourceLoader.load(
				scene_path,
				"PackedScene"
			)
			as PackedScene
		)

		if loaded_scene == null:
			continue

		var picker := _add_scene_row(
			loaded_scene,
			false,
			enabled_scene_paths.has(scene_path)
		)

		if scene_path == active_scene_path:
			active_picker = picker
			selected_scene = loaded_scene

	if not is_instance_valid(
		active_picker
	):
		_select_first_available_scene()

	_load_active_scene_settings(
		false
	)

	is_loading_configuration = false


func _load_interface_settings(
	config: ConfigFile
) -> void:
	var stored_language := str(
		config.get_value(
			INTERFACE_SECTION,
			CONFIG_INTERFACE_LANGUAGE,
			LANGUAGE_ENGLISH
		)
	)

	if (
		stored_language != LANGUAGE_ENGLISH
		and stored_language != LANGUAGE_ARABIC
	):
		stored_language = LANGUAGE_ENGLISH

	current_language = LANGUAGE_ENGLISH


func _load_brush_settings(
	config: ConfigFile
) -> void:
	var use_selected_parent := bool(
		config.get_value(
			SETTINGS_SECTION,
			CONFIG_USE_SELECTED_PARENT,
			false
		)
	)
	if is_instance_valid(use_selected_parent_toggle):
		use_selected_parent_toggle.set_pressed_no_signal(use_selected_parent)

	brush_radius = maxf(
		float(
			config.get_value(
				SETTINGS_SECTION,
				CONFIG_BRUSH_RADIUS,
				brush_radius
			)
		),
		0.5
	)

	instances_per_click = maxi(
		int(
			config.get_value(
				SETTINGS_SECTION,
				CONFIG_INSTANCES_PER_STAMP,
				instances_per_click
			)
		),
		1
	)

	minimum_spacing = maxf(
		float(
			config.get_value(
				SETTINGS_SECTION,
				CONFIG_MINIMUM_SPACING,
				minimum_spacing
			)
		),
		0.0
	)

	random_y_rotation = bool(
		config.get_value(
			SETTINGS_SECTION,
			CONFIG_RANDOM_Y_ROTATION,
			random_y_rotation
		)
	)

	align_to_surface = bool(
		config.get_value(
			SETTINGS_SECTION,
			CONFIG_ALIGN_TO_SURFACE,
			align_to_surface
		)
	)

	maximum_slope_degrees = clampf(
		float(
			config.get_value(
				SETTINGS_SECTION,
				CONFIG_MAXIMUM_SLOPE,
				maximum_slope_degrees
			)
		),
		0.0,
		90.0
	)

	height_offset = float(
		config.get_value(
			SETTINGS_SECTION,
			CONFIG_HEIGHT_OFFSET,
			height_offset
		)
	)

	height_offset_mode = int(
		config.get_value(
			SETTINGS_SECTION,
			CONFIG_HEIGHT_OFFSET_MODE,
			HeightOffsetMode.SURFACE_NORMAL
		)
	)

	height_offset_mode = clampi(
		height_offset_mode,
		HeightOffsetMode.WORLD_Y,
		HeightOffsetMode.SURFACE_NORMAL
	)

	random_scale_enabled = bool(
		config.get_value(
			SETTINGS_SECTION,
			CONFIG_RANDOM_SCALE_ENABLED,
			random_scale_enabled
		)
	)

	minimum_scale = maxf(
		float(
			config.get_value(
				SETTINGS_SECTION,
				CONFIG_MINIMUM_SCALE,
				minimum_scale
			)
		),
		0.01
	)

	maximum_scale = maxf(
		float(
			config.get_value(
				SETTINGS_SECTION,
				CONFIG_MAXIMUM_SCALE,
				maximum_scale
			)
		),
		0.01
	)

	if minimum_scale > maximum_scale:
		maximum_scale = minimum_scale

	_apply_settings_to_controls()


func _load_scene_brush_settings(
	config: ConfigFile
) -> void:
	scene_brush_settings.clear()

	var stored_profiles: Variant = config.get_value(
		SCENE_SETTINGS_SECTION,
		CONFIG_SCENE_SETTINGS,
		{}
	)

	if typeof(
		stored_profiles
	) != TYPE_DICTIONARY:
		return

	var profiles_dictionary: Dictionary = (
		stored_profiles
	)

	for stored_scene_path in profiles_dictionary:
		var scene_path := str(
			stored_scene_path
		)

		var stored_profile: Variant = (
			profiles_dictionary[
				stored_scene_path
			]
		)

		if typeof(
			stored_profile
		) != TYPE_DICTIONARY:
			continue

		var profile_dictionary: Dictionary = (
			stored_profile
		)

		scene_brush_settings[
			scene_path
		] = profile_dictionary.duplicate(
			true
		)


func _get_active_scene_settings_key() -> String:
	if selected_scene == null:
		return ""

	return selected_scene.resource_path


func _capture_current_brush_settings() -> Dictionary:
	return {
		CONFIG_BRUSH_RADIUS:
			brush_radius,

		CONFIG_INSTANCES_PER_STAMP:
			instances_per_click,

		CONFIG_MINIMUM_SPACING:
			minimum_spacing,

		CONFIG_RANDOM_Y_ROTATION:
			random_y_rotation,

		CONFIG_ALIGN_TO_SURFACE:
			align_to_surface,

		CONFIG_MAXIMUM_SLOPE:
			maximum_slope_degrees,

		CONFIG_HEIGHT_OFFSET:
			height_offset,

		CONFIG_HEIGHT_OFFSET_MODE:
			height_offset_mode,

		CONFIG_RANDOM_SCALE_ENABLED:
			random_scale_enabled,

		CONFIG_MINIMUM_SCALE:
			minimum_scale,

		CONFIG_MAXIMUM_SCALE:
			maximum_scale,
	}


func _store_current_scene_settings() -> void:
	if (
		is_loading_configuration
		or is_applying_scene_settings
	):
		return

	var scene_key := (
		_get_active_scene_settings_key()
	)

	if scene_key.is_empty():
		return

	scene_brush_settings[
		scene_key
	] = _capture_current_brush_settings()


func _load_active_scene_settings(
	emit_changes: bool = true
) -> void:
	var scene_key := (
		_get_active_scene_settings_key()
	)

	if scene_key.is_empty():
		return

	if not scene_brush_settings.has(
		scene_key
	):
		scene_brush_settings[
			scene_key
		] = _capture_current_brush_settings()

		if emit_changes:
			_emit_all_brush_settings_changed()

		return

	var stored_profile: Variant = (
		scene_brush_settings[
			scene_key
		]
	)

	if typeof(
		stored_profile
	) != TYPE_DICTIONARY:
		scene_brush_settings[
			scene_key
		] = _capture_current_brush_settings()

		if emit_changes:
			_emit_all_brush_settings_changed()

		return

	var profile: Dictionary = stored_profile

	_apply_brush_settings_profile(
		profile
	)

	if emit_changes:
		_emit_all_brush_settings_changed()


func _apply_brush_settings_profile(
	profile: Dictionary
) -> void:
	is_applying_scene_settings = true

	brush_radius = maxf(
		float(
			profile.get(
				CONFIG_BRUSH_RADIUS,
				brush_radius
			)
		),
		0.5
	)

	instances_per_click = maxi(
		int(
			profile.get(
				CONFIG_INSTANCES_PER_STAMP,
				instances_per_click
			)
		),
		1
	)

	minimum_spacing = maxf(
		float(
			profile.get(
				CONFIG_MINIMUM_SPACING,
				minimum_spacing
			)
		),
		0.0
	)

	random_y_rotation = bool(
		profile.get(
			CONFIG_RANDOM_Y_ROTATION,
			random_y_rotation
		)
	)

	align_to_surface = bool(
		profile.get(
			CONFIG_ALIGN_TO_SURFACE,
			align_to_surface
		)
	)

	maximum_slope_degrees = clampf(
		float(
			profile.get(
				CONFIG_MAXIMUM_SLOPE,
				maximum_slope_degrees
			)
		),
		0.0,
		90.0
	)

	height_offset = float(
		profile.get(
			CONFIG_HEIGHT_OFFSET,
			height_offset
		)
	)

	height_offset_mode = clampi(
		int(
			profile.get(
				CONFIG_HEIGHT_OFFSET_MODE,
				height_offset_mode
			)
		),
		HeightOffsetMode.WORLD_Y,
		HeightOffsetMode.SURFACE_NORMAL
	)

	random_scale_enabled = bool(
		profile.get(
			CONFIG_RANDOM_SCALE_ENABLED,
			random_scale_enabled
		)
	)

	minimum_scale = maxf(
		float(
			profile.get(
				CONFIG_MINIMUM_SCALE,
				minimum_scale
			)
		),
		0.01
	)

	maximum_scale = maxf(
		float(
			profile.get(
				CONFIG_MAXIMUM_SCALE,
				maximum_scale
			)
		),
		0.01
	)

	if minimum_scale > maximum_scale:
		maximum_scale = minimum_scale

	_apply_settings_to_controls()
	_update_controls()

	is_applying_scene_settings = false


func _emit_all_brush_settings_changed() -> void:
	brush_radius_changed.emit(
		brush_radius
	)

	instances_per_click_changed.emit(
		instances_per_click
	)

	minimum_spacing_changed.emit(
		minimum_spacing
	)

	random_y_rotation_changed.emit(
		random_y_rotation
	)

	align_to_surface_changed.emit(
		align_to_surface
	)

	maximum_slope_changed.emit(
		maximum_slope_degrees
	)

	height_offset_changed.emit(
		height_offset
	)

	height_offset_mode_changed.emit(
		height_offset_mode
	)

	random_scale_enabled_changed.emit(
		random_scale_enabled
	)

	minimum_scale_changed.emit(
		minimum_scale
	)

	maximum_scale_changed.emit(
		maximum_scale
	)


func _apply_settings_to_controls() -> void:
	if is_instance_valid(radius_spin_box):
		radius_spin_box.set_value_no_signal(
			brush_radius
		)

	if is_instance_valid(instances_spin_box):
		instances_spin_box.set_value_no_signal(
			float(instances_per_click)
		)

	if is_instance_valid(spacing_spin_box):
		spacing_spin_box.set_value_no_signal(
			minimum_spacing
		)

	if is_instance_valid(random_rotation_toggle):
		random_rotation_toggle.set_pressed_no_signal(
			random_y_rotation
		)

	if is_instance_valid(align_surface_toggle):
		align_surface_toggle.set_pressed_no_signal(
			align_to_surface
		)

	if is_instance_valid(maximum_slope_spin_box):
		maximum_slope_spin_box.set_value_no_signal(
			maximum_slope_degrees
		)

	if is_instance_valid(height_offset_spin_box):
		height_offset_spin_box.set_value_no_signal(
			height_offset
		)

	if is_instance_valid(height_offset_mode_option):
		height_offset_mode_option.select(
			height_offset_mode
		)

	if is_instance_valid(random_scale_toggle):
		random_scale_toggle.set_pressed_no_signal(
			random_scale_enabled
		)

	if is_instance_valid(minimum_scale_spin_box):
		minimum_scale_spin_box.set_value_no_signal(
			minimum_scale
		)

	if is_instance_valid(maximum_scale_spin_box):
		maximum_scale_spin_box.set_value_no_signal(
			maximum_scale
		)


func _emit_loaded_state() -> void:
	_apply_language()
	_update_scene_interface()

	_emit_palette_changed()
	_emit_active_scene_changed()
	use_selected_parent_changed.emit(
		use_selected_parent_toggle.button_pressed
	)

	_emit_all_brush_settings_changed()

	var valid_scene_count := (
		_get_valid_scene_pickers().size()
	)

	if valid_scene_count <= 0:
		_set_status(
			"No Scenes Selected"
		)

		return

	_set_status(
		"Palette Restored: %d Scene(s)"
		% valid_scene_count
	)


# -----------------------------------------------------------------------------
# SCENE PALETTE STATE
# -----------------------------------------------------------------------------

func _update_scene_interface() -> void:
	_validate_active_picker()
	var enabled_scene_count := get_scene_palette().size()

	if is_instance_valid(palette_title_label):
		palette_title_label.text = "Drag .tscn scenes here — %d enabled" % enabled_scene_count

	for entry in scene_rows:
		var picker := _get_picker_from_row(entry)
		var enabled_toggle := entry.get("enabled_toggle") as CheckBox
		var scene_name_label := entry.get("name_label") as Label
		var has_scene := _picker_has_scene(picker)

		if is_instance_valid(enabled_toggle):
			enabled_toggle.disabled = not has_scene
			if has_scene:
				var packed_scene := picker.edited_resource as PackedScene
				enabled_toggle.tooltip_text = packed_scene.resource_path
			else:
				enabled_toggle.tooltip_text = "Drag a PackedScene into this tile."

		if is_instance_valid(scene_name_label):
			if has_scene:
				var packed_scene := picker.edited_resource as PackedScene
				scene_name_label.text = _get_scene_display_name(packed_scene)
				scene_name_label.tooltip_text = packed_scene.resource_path
			else:
				scene_name_label.text = "Empty"

	if is_instance_valid(active_picker):
		selected_scene = active_picker.edited_resource as PackedScene
	else:
		selected_scene = null

	_update_controls()


func _validate_active_picker() -> void:
	if (
		is_instance_valid(active_picker)
		and _picker_belongs_to_palette(
			active_picker
		)
		and _picker_has_scene(
			active_picker
		)
	):
		return

	active_picker = null
	selected_scene = null

	_select_first_available_scene()


func _picker_belongs_to_palette(
	picker: EditorResourcePicker
) -> bool:
	for entry in scene_rows:
		if _get_picker_from_row(
			entry
		) == picker:
			return true

	return false


func _get_valid_scene_pickers() -> Array[EditorResourcePicker]:
	var result: Array[EditorResourcePicker] = []

	for entry in scene_rows:
		var picker := _get_picker_from_row(
			entry
		)

		if _picker_has_scene(
			picker
		):
			result.append(
				picker
			)

	return result


func _get_picker_from_row(
	entry: Dictionary
) -> EditorResourcePicker:
	return (
		entry.get("picker")
		as EditorResourcePicker
	)


func _picker_has_scene(
	picker: EditorResourcePicker
) -> bool:
	return (
		is_instance_valid(picker)
		and picker.edited_resource is PackedScene
	)


func _get_scene_display_name(
	scene: PackedScene
) -> String:
	if scene == null:
		return "None"

	if scene.resource_path.is_empty():
		return _tr(
			"unsaved_scene"
		)

	return scene.resource_path.get_file()


func _emit_active_scene_changed() -> void:
	_validate_active_picker()

	if not is_instance_valid(
		active_picker
	):
		selected_scene = null

		selected_scene_changed.emit(
			null
		)

		_disable_brush_if_no_scene()
		return

	selected_scene = (
		active_picker.edited_resource
		as PackedScene
	)

	selected_scene_changed.emit(
		selected_scene
	)

	_disable_brush_if_no_scene()


func _emit_palette_changed() -> void:
	scene_palette_changed.emit(
		get_scene_palette()
	)


func get_scene_palette() -> Array:
	var scenes: Array = []

	for entry in scene_rows:
		var picker := _get_picker_from_row(entry)
		var enabled_toggle := entry.get("enabled_toggle") as CheckBox
		if not _picker_has_scene(picker):
			continue
		if not is_instance_valid(enabled_toggle) or not enabled_toggle.button_pressed:
			continue

		var packed_scene := (
			picker.edited_resource
			as PackedScene
		)

		if packed_scene != null:
			scenes.append(
				packed_scene
			)

	return scenes


# -----------------------------------------------------------------------------
# BRUSH SETTINGS
# -----------------------------------------------------------------------------

func _create_brush_toggle() -> void:
	var separator := HSeparator.new()
	separator.name = "BrushSeparator"

	controls_container.add_child(
		separator
	)

	brush_toggle = CheckButton.new()
	brush_toggle.name = "BrushToggle"
	brush_toggle.text = "Enable Brush"
	brush_toggle.button_pressed = false

	brush_toggle.toggled.connect(
		_on_brush_toggled
	)

	controls_container.add_child(
		brush_toggle
	)


func _on_brush_toggled(
	enabled: bool
) -> void:
	if enabled and get_scene_palette().is_empty():
		_disable_brush()

		_set_status(
			"Tick At Least One Scene First"
		)

		return

	brush_enabled = enabled

	if brush_enabled:
		_set_status(
			"Brush Enabled — Randomising %d Scene(s)"
			% get_scene_palette().size()
		)
	else:
		_set_status(
			"Brush Disabled"
		)

	brush_enabled_changed.emit(
		brush_enabled
	)


func _disable_brush_if_no_scene() -> void:
	if get_scene_palette().is_empty():
		_disable_brush()


func _disable_brush() -> void:
	brush_enabled = false

	if is_instance_valid(
		brush_toggle
	):
		brush_toggle.set_pressed_no_signal(
			false
		)

	brush_enabled_changed.emit(
		false
	)


func _create_radius_control() -> void:
	var row := _create_setting_row(
		"RadiusContainer",
		"Brush Radius"
	)

	brush_radius_label = (
		row.get_child(0)
		as Label
	)

	radius_spin_box = SpinBox.new()
	radius_spin_box.name = "RadiusSpinBox"
	radius_spin_box.min_value = 0.5
	radius_spin_box.max_value = 100.0
	radius_spin_box.step = 0.5
	radius_spin_box.value = brush_radius
	radius_spin_box.allow_greater = true
	radius_spin_box.suffix = " m"

	radius_spin_box.custom_minimum_size.x = (
		105.0
	)

	radius_spin_box.value_changed.connect(
		_on_radius_changed
	)

	row.add_child(
		radius_spin_box
	)


func _on_radius_changed(
	value: float
) -> void:
	brush_radius = maxf(
		value,
		0.5
	)

	brush_radius_changed.emit(
		brush_radius
	)

	_save_configuration()


func _create_instances_control() -> void:
	var row := _create_setting_row(
		"InstancesContainer",
		"Instances Per Stamp"
	)

	instances_label = (
		row.get_child(0)
		as Label
	)

	instances_spin_box = SpinBox.new()
	instances_spin_box.name = "InstancesSpinBox"
	instances_spin_box.min_value = 1.0
	instances_spin_box.max_value = 100.0
	instances_spin_box.step = 1.0
	instances_spin_box.value = instances_per_click
	instances_spin_box.rounded = true
	instances_spin_box.allow_greater = true

	instances_spin_box.custom_minimum_size.x = (
		105.0
	)

	instances_spin_box.value_changed.connect(
		_on_instances_changed
	)

	row.add_child(
		instances_spin_box
	)


func _on_instances_changed(
	value: float
) -> void:
	instances_per_click = maxi(
		roundi(value),
		1
	)

	instances_per_click_changed.emit(
		instances_per_click
	)

	_save_configuration()


func _create_spacing_control() -> void:
	var row := _create_setting_row(
		"SpacingContainer",
		"Minimum Spacing"
	)

	spacing_label = (
		row.get_child(0)
		as Label
	)

	spacing_spin_box = SpinBox.new()
	spacing_spin_box.name = "SpacingSpinBox"
	spacing_spin_box.min_value = 0.0
	spacing_spin_box.max_value = 100.0
	spacing_spin_box.step = 0.25
	spacing_spin_box.value = minimum_spacing
	spacing_spin_box.allow_greater = true
	spacing_spin_box.suffix = " m"

	spacing_spin_box.custom_minimum_size.x = (
		105.0
	)

	spacing_spin_box.value_changed.connect(
		_on_spacing_changed
	)

	row.add_child(
		spacing_spin_box
	)


func _on_spacing_changed(
	value: float
) -> void:
	minimum_spacing = maxf(
		value,
		0.0
	)

	minimum_spacing_changed.emit(
		minimum_spacing
	)

	_save_configuration()


func _create_random_rotation_control() -> void:
	random_rotation_toggle = CheckButton.new()
	random_rotation_toggle.name = "RandomRotationToggle"
	random_rotation_toggle.text = "Random Y Rotation"

	random_rotation_toggle.button_pressed = (
		random_y_rotation
	)

	random_rotation_toggle.toggled.connect(
		_on_random_rotation_toggled
	)

	controls_container.add_child(
		random_rotation_toggle
	)


func _on_random_rotation_toggled(
	enabled: bool
) -> void:
	random_y_rotation = enabled

	random_y_rotation_changed.emit(
		random_y_rotation
	)

	_save_configuration()


func _create_align_surface_control() -> void:
	align_surface_toggle = CheckButton.new()
	align_surface_toggle.name = "AlignSurfaceToggle"
	align_surface_toggle.text = "Rotate With Surface"
	align_surface_toggle.tooltip_text = (
		"Rotates the instance to follow the surface slope."
	)

	align_surface_toggle.button_pressed = (
		align_to_surface
	)

	align_surface_toggle.toggled.connect(
		_on_align_surface_toggled
	)

	controls_container.add_child(
		align_surface_toggle
	)


func _on_align_surface_toggled(
	enabled: bool
) -> void:
	align_to_surface = enabled

	align_to_surface_changed.emit(
		align_to_surface
	)

	_save_configuration()


# -----------------------------------------------------------------------------
# SURFACE-SLOPE SETTINGS
# -----------------------------------------------------------------------------

func _create_maximum_slope_control() -> void:
	var separator := HSeparator.new()
	separator.name = "MaximumSlopeSeparator"

	controls_container.add_child(
		separator
	)

	var row := _create_setting_row(
		"MaximumSlopeContainer",
		"Maximum Slope"
	)

	maximum_slope_label = (
		row.get_child(0)
		as Label
	)

	maximum_slope_spin_box = SpinBox.new()
	maximum_slope_spin_box.name = "MaximumSlopeSpinBox"

	maximum_slope_spin_box.min_value = 0.0
	maximum_slope_spin_box.max_value = 90.0
	maximum_slope_spin_box.step = 1.0

	maximum_slope_spin_box.value = (
		maximum_slope_degrees
	)

	maximum_slope_spin_box.suffix = "°"

	maximum_slope_spin_box.custom_minimum_size.x = (
		105.0
	)

	maximum_slope_spin_box.tooltip_text = (
		"0° allows flat surfaces only. "
		+ "90° allows nearly all surface slopes."
	)

	maximum_slope_spin_box.value_changed.connect(
		_on_maximum_slope_changed
	)

	row.add_child(
		maximum_slope_spin_box
	)


func _on_maximum_slope_changed(
	value: float
) -> void:
	maximum_slope_degrees = clampf(
		value,
		0.0,
		90.0
	)

	maximum_slope_changed.emit(
		maximum_slope_degrees
	)

	_save_configuration()


# -----------------------------------------------------------------------------
# HEIGHT-OFFSET SETTINGS
# -----------------------------------------------------------------------------

func _create_height_offset_controls() -> void:
	var separator := HSeparator.new()
	separator.name = "HeightOffsetSeparator"

	controls_container.add_child(
		separator
	)

	var offset_row := _create_setting_row(
		"HeightOffsetContainer",
		"Height Offset"
	)

	height_offset_label = (
		offset_row.get_child(0)
		as Label
	)

	height_offset_spin_box = SpinBox.new()
	height_offset_spin_box.name = "HeightOffsetSpinBox"

	height_offset_spin_box.min_value = -100.0
	height_offset_spin_box.max_value = 100.0
	height_offset_spin_box.step = 0.05
	height_offset_spin_box.value = height_offset

	height_offset_spin_box.allow_lesser = true
	height_offset_spin_box.allow_greater = true
	height_offset_spin_box.suffix = " m"

	height_offset_spin_box.custom_minimum_size.x = (
		105.0
	)

	height_offset_spin_box.value_changed.connect(
		_on_height_offset_changed
	)

	offset_row.add_child(
		height_offset_spin_box
	)

	var direction_row := _create_setting_row(
		"HeightOffsetModeContainer",
		"Offset Direction"
	)

	height_offset_mode_label = (
		direction_row.get_child(0)
		as Label
	)

	height_offset_mode_option = OptionButton.new()

	height_offset_mode_option.name = (
		"HeightOffsetModeOption"
	)

	height_offset_mode_option.custom_minimum_size.x = (
		150.0
	)

	height_offset_mode_option.add_item(
		"World Y",
		HeightOffsetMode.WORLD_Y
	)

	height_offset_mode_option.add_item(
		"Surface Normal",
		HeightOffsetMode.SURFACE_NORMAL
	)

	height_offset_mode_option.select(
		height_offset_mode
	)

	height_offset_mode_option.item_selected.connect(
		_on_height_offset_mode_selected
	)

	direction_row.add_child(
		height_offset_mode_option
	)

	height_offset_help_label = Label.new()
	height_offset_help_label.name = "HeightOffsetHelpLabel"
	height_offset_help_label.text = (
		"The offset direction moves the instance position only. "
		+ "Enable Rotate With Surface to change its tilt."
	)

	height_offset_help_label.autowrap_mode = (
		TextServer.AUTOWRAP_WORD_SMART
	)

	height_offset_help_label.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)

	height_offset_help_label.modulate = Color(
		1.0,
		1.0,
		1.0,
		0.72
	)

	controls_container.add_child(
		height_offset_help_label
	)


func _on_height_offset_changed(
	value: float
) -> void:
	height_offset = value

	height_offset_changed.emit(
		height_offset
	)

	_save_configuration()


func _on_height_offset_mode_selected(
	index: int
) -> void:
	height_offset_mode = clampi(
		index,
		HeightOffsetMode.WORLD_Y,
		HeightOffsetMode.SURFACE_NORMAL
	)

	height_offset_mode_changed.emit(
		height_offset_mode
	)

	_save_configuration()


# -----------------------------------------------------------------------------
# RANDOM-SCALE SETTINGS
# -----------------------------------------------------------------------------

func _create_random_scale_controls() -> void:
	var separator := HSeparator.new()
	separator.name = "RandomScaleSeparator"

	controls_container.add_child(
		separator
	)

	random_scale_toggle = CheckButton.new()
	random_scale_toggle.name = "RandomScaleToggle"
	random_scale_toggle.text = "Random Scale"

	random_scale_toggle.button_pressed = (
		random_scale_enabled
	)

	random_scale_toggle.toggled.connect(
		_on_random_scale_toggled
	)

	controls_container.add_child(
		random_scale_toggle
	)

	var minimum_row := _create_setting_row(
		"MinimumScaleContainer",
		"Minimum Scale"
	)

	minimum_scale_label = (
		minimum_row.get_child(0)
		as Label
	)

	minimum_scale_spin_box = SpinBox.new()

	minimum_scale_spin_box.name = (
		"MinimumScaleSpinBox"
	)

	minimum_scale_spin_box.min_value = 0.01
	minimum_scale_spin_box.max_value = 100.0
	minimum_scale_spin_box.step = 0.05
	minimum_scale_spin_box.value = minimum_scale
	minimum_scale_spin_box.allow_greater = true

	minimum_scale_spin_box.custom_minimum_size.x = (
		105.0
	)

	minimum_scale_spin_box.value_changed.connect(
		_on_minimum_scale_changed
	)

	minimum_row.add_child(
		minimum_scale_spin_box
	)

	var maximum_row := _create_setting_row(
		"MaximumScaleContainer",
		"Maximum Scale"
	)

	maximum_scale_label = (
		maximum_row.get_child(0)
		as Label
	)

	maximum_scale_spin_box = SpinBox.new()

	maximum_scale_spin_box.name = (
		"MaximumScaleSpinBox"
	)

	maximum_scale_spin_box.min_value = 0.01
	maximum_scale_spin_box.max_value = 100.0
	maximum_scale_spin_box.step = 0.05
	maximum_scale_spin_box.value = maximum_scale
	maximum_scale_spin_box.allow_greater = true

	maximum_scale_spin_box.custom_minimum_size.x = (
		105.0
	)

	maximum_scale_spin_box.value_changed.connect(
		_on_maximum_scale_changed
	)

	maximum_row.add_child(
		maximum_scale_spin_box
	)


func _on_random_scale_toggled(
	enabled: bool
) -> void:
	random_scale_enabled = enabled

	random_scale_enabled_changed.emit(
		random_scale_enabled
	)

	_update_controls()
	_save_configuration()


func _on_minimum_scale_changed(
	value: float
) -> void:
	minimum_scale = maxf(
		value,
		0.01
	)

	if minimum_scale > maximum_scale:
		maximum_scale = minimum_scale

		if is_instance_valid(
			maximum_scale_spin_box
		):
			maximum_scale_spin_box.set_value_no_signal(
				maximum_scale
			)

		maximum_scale_changed.emit(
			maximum_scale
		)

	minimum_scale_changed.emit(
		minimum_scale
	)

	_save_configuration()


func _on_maximum_scale_changed(
	value: float
) -> void:
	maximum_scale = maxf(
		value,
		0.01
	)

	if maximum_scale < minimum_scale:
		minimum_scale = maximum_scale

		if is_instance_valid(
			minimum_scale_spin_box
		):
			minimum_scale_spin_box.set_value_no_signal(
				minimum_scale
			)

		minimum_scale_changed.emit(
			minimum_scale
		)

	maximum_scale_changed.emit(
		maximum_scale
	)

	_save_configuration()


func _create_setting_row(
	row_name: String,
	label_text: String
) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = row_name

	row.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)

	var label := Label.new()
	label.name = "%sLabel" % row_name
	label.text = label_text

	label.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)

	row.add_child(
		label
	)

	controls_container.add_child(
		row
	)

	return row


func _update_controls() -> void:
	var has_active_scene := (
		not get_scene_palette().is_empty()
	)

	if is_instance_valid(
		brush_toggle
	):
		brush_toggle.disabled = (
			not has_active_scene
		)

	if is_instance_valid(
		radius_spin_box
	):
		radius_spin_box.editable = (
			has_active_scene
		)

	if is_instance_valid(
		instances_spin_box
	):
		instances_spin_box.editable = (
			has_active_scene
		)

	if is_instance_valid(
		spacing_spin_box
	):
		spacing_spin_box.editable = (
			has_active_scene
		)

	if is_instance_valid(
		random_rotation_toggle
	):
		random_rotation_toggle.disabled = (
			not has_active_scene
		)

	if is_instance_valid(
		align_surface_toggle
	):
		align_surface_toggle.disabled = (
			not has_active_scene
		)

	if is_instance_valid(
		maximum_slope_spin_box
	):
		maximum_slope_spin_box.editable = (
			has_active_scene
		)

	if is_instance_valid(
		height_offset_spin_box
	):
		height_offset_spin_box.editable = (
			has_active_scene
		)

	if is_instance_valid(
		height_offset_mode_option
	):
		height_offset_mode_option.disabled = (
			not has_active_scene
		)

	if is_instance_valid(
		random_scale_toggle
	):
		random_scale_toggle.disabled = (
			not has_active_scene
		)

	var scale_controls_enabled := (
		has_active_scene
		and random_scale_enabled
	)

	if is_instance_valid(
		minimum_scale_spin_box
	):
		minimum_scale_spin_box.editable = (
			scale_controls_enabled
		)

	if is_instance_valid(
		maximum_scale_spin_box
	):
		maximum_scale_spin_box.editable = (
			scale_controls_enabled
		)


# -----------------------------------------------------------------------------
# PUBLIC SETTING ACCESSORS
# -----------------------------------------------------------------------------

func get_selected_scene() -> PackedScene:
	return selected_scene


func get_active_scene_index() -> int:
	return (
		_get_valid_scene_pickers().find(
			active_picker
		)
	)


func is_brush_enabled() -> bool:
	return brush_enabled


func get_brush_radius() -> float:
	return brush_radius


func get_instances_per_click() -> int:
	return instances_per_click


func get_minimum_spacing() -> float:
	return minimum_spacing


func is_random_y_rotation_enabled() -> bool:
	return random_y_rotation


func is_align_to_surface_enabled() -> bool:
	return align_to_surface


func get_maximum_slope() -> float:
	return maximum_slope_degrees


func get_height_offset() -> float:
	return height_offset


func get_height_offset_mode() -> int:
	return height_offset_mode


func is_random_scale_enabled() -> bool:
	return random_scale_enabled


func get_minimum_scale() -> float:
	return minimum_scale


func get_maximum_scale() -> float:
	return maximum_scale


func get_interface_language() -> String:
	return current_language
