@tool
extends EditorScript
## Generador de tema visual para SIRE
## Ejecutar desde Editor -> Run -> Run as Tool para regenerar el tema

const BG_DARK = Color("#0f172a")
const BG_PANEL = Color("#1e293b")
const BG_PANEL_TRANSPARENT = Color("#1e293bcc")
const ACCENT_GOLD = Color("#FFD54F")
const ACCENT_GOLD_DARK = Color("#FFA000")
const TEXT_WHITE = Color("#f1f5f9")
const TEXT_GRAY = Color("#94a3b8")
const BUTTON_HOVER = Color("#334155")
const BUTTON_PRESSED = Color("#475569")
const RED = Color("#ef4444")
const GREEN = Color("#22c55e")
const BLUE = Color("#3b82f6")

func _run():
	var theme = Theme.new()
	
	# Fuentes
	var default_font = SystemFont.new()
	default_font.font_names = ["Inter", "Roboto", "Noto Sans", "Arial", "sans-serif"]
	default_font.font_weight = 600
	theme.default_font = default_font
	theme.default_font_size = 16
	
	var title_font = SystemFont.new()
	title_font.font_names = ["Inter", "Roboto", "Noto Sans", "Arial", "sans-serif"]
	title_font.font_weight = 800
	
	# Estilos de panel
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = BG_PANEL_TRANSPARENT
	panel_style.border_color = ACCENT_GOLD
	panel_style.border_width_left = 1
	panel_style.border_width_top = 1
	panel_style.border_width_right = 1
	panel_style.border_width_bottom = 1
	panel_style.corner_radius_top_left = 8
	panel_style.corner_radius_top_right = 8
	panel_style.corner_radius_bottom_left = 8
	panel_style.corner_radius_bottom_right = 8
	panel_style.content_margin_left = 12
	panel_style.content_margin_top = 12
	panel_style.content_margin_right = 12
	panel_style.content_margin_bottom = 12
	
	var panel_no_border = StyleBoxFlat.new()
	panel_no_border.bg_color = BG_PANEL_TRANSPARENT
	panel_no_border.corner_radius_top_left = 8
	panel_no_border.corner_radius_top_right = 8
	panel_no_border.corner_radius_bottom_left = 8
	panel_no_border.corner_radius_bottom_right = 8
	
	theme.set_stylebox("panel", "Panel", panel_style)
	theme.set_stylebox("panel", "PanelContainer", panel_style)
	
	# Estilos de botón
	var button_normal = StyleBoxFlat.new()
	button_normal.bg_color = BUTTON_HOVER
	button_normal.corner_radius_top_left = 6
	button_normal.corner_radius_top_right = 6
	button_normal.corner_radius_bottom_left = 6
	button_normal.corner_radius_bottom_right = 6
	button_normal.content_margin_left = 20
	button_normal.content_margin_top = 10
	button_normal.content_margin_right = 20
	button_normal.content_margin_bottom = 10
	
	var button_hover = StyleBoxFlat.new()
	button_hover.bg_color = Color("#475569")
	button_hover.corner_radius_top_left = 6
	button_hover.corner_radius_top_right = 6
	button_hover.corner_radius_bottom_left = 6
	button_hover.corner_radius_bottom_right = 6
	button_hover.content_margin_left = 20
	button_hover.content_margin_top = 10
	button_hover.content_margin_right = 20
	button_hover.content_margin_bottom = 10
	
	var button_pressed = StyleBoxFlat.new()
	button_pressed.bg_color = ACCENT_GOLD_DARK
	button_pressed.corner_radius_top_left = 6
	button_pressed.corner_radius_top_right = 6
	button_pressed.corner_radius_bottom_left = 6
	button_pressed.corner_radius_bottom_right = 6
	button_pressed.content_margin_left = 20
	button_pressed.content_margin_top = 10
	button_pressed.content_margin_right = 20
	button_pressed.content_margin_bottom = 10
	
	var button_focus = StyleBoxFlat.new()
	button_focus.bg_color = Color("#334155")
	button_focus.border_color = ACCENT_GOLD
	button_focus.border_width_left = 2
	button_focus.border_width_top = 2
	button_focus.border_width_right = 2
	button_focus.border_width_bottom = 2
	button_focus.corner_radius_top_left = 6
	button_focus.corner_radius_top_right = 6
	button_focus.corner_radius_bottom_left = 6
	button_focus.corner_radius_bottom_right = 6
	button_focus.content_margin_left = 20
	button_focus.content_margin_top = 10
	button_focus.content_margin_right = 20
	button_focus.content_margin_bottom = 10
	
	var button_disabled = StyleBoxFlat.new()
	button_disabled.bg_color = Color("#1e293b")
	button_disabled.corner_radius_top_left = 6
	button_disabled.corner_radius_top_right = 6
	button_disabled.corner_radius_bottom_left = 6
	button_disabled.corner_radius_bottom_right = 6
	button_disabled.content_margin_left = 20
	button_disabled.content_margin_top = 10
	button_disabled.content_margin_right = 20
	button_disabled.content_margin_bottom = 10
	
	theme.set_stylebox("normal", "Button", button_normal)
	theme.set_stylebox("hover", "Button", button_hover)
	theme.set_stylebox("pressed", "Button", button_pressed)
	theme.set_stylebox("focus", "Button", button_focus)
	theme.set_stylebox("disabled", "Button", button_disabled)
	
	# Colores de botón
	theme.set_color("font_color", "Button", TEXT_WHITE)
	theme.set_color("font_hover_color", "Button", ACCENT_GOLD)
	theme.set_color("font_pressed_color", "Button", BG_DARK)
	theme.set_color("font_focus_color", "Button", ACCENT_GOLD)
	theme.set_color("font_disabled_color", "Button", TEXT_GRAY)
	
	# Estilos de Label
	theme.set_color("font_color", "Label", TEXT_WHITE)
	theme.set_font_size("font_size", "Label", 16)
	
	# Estilos de RichTextLabel
	theme.set_color("default_color", "RichTextLabel", TEXT_WHITE)
	theme.set_font_size("normal_font_size", "RichTextLabel", 14)
	
	# Estilos de ProgressBar
	var progress_bg = StyleBoxFlat.new()
	progress_bg.bg_color = BG_DARK
	progress_bg.corner_radius_top_left = 4
	progress_bg.corner_radius_top_right = 4
	progress_bg.corner_radius_bottom_left = 4
	progress_bg.corner_radius_bottom_right = 4
	
	var progress_fill = StyleBoxFlat.new()
	progress_fill.bg_color = ACCENT_GOLD
	progress_fill.corner_radius_top_left = 4
	progress_fill.corner_radius_top_right = 4
	progress_fill.corner_radius_bottom_left = 4
	progress_fill.corner_radius_bottom_right = 4
	
	theme.set_stylebox("background", "ProgressBar", progress_bg)
	theme.set_stylebox("fill", "ProgressBar", progress_fill)
	theme.set_color("font_color", "ProgressBar", TEXT_WHITE)
	
	# Estilos de OptionButton
	theme.set_stylebox("normal", "OptionButton", button_normal)
	theme.set_stylebox("hover", "OptionButton", button_hover)
	theme.set_stylebox("pressed", "OptionButton", button_pressed)
	theme.set_color("font_color", "OptionButton", TEXT_WHITE)
	theme.set_color("font_hover_color", "OptionButton", ACCENT_GOLD)
	
	# Estilos de ItemList / PopupMenu
	var popup_panel = StyleBoxFlat.new()
	popup_panel.bg_color = BG_PANEL
	popup_panel.corner_radius_top_left = 6
	popup_panel.corner_radius_top_right = 6
	popup_panel.corner_radius_bottom_left = 6
	popup_panel.corner_radius_bottom_right = 6
	
	theme.set_stylebox("panel", "PopupMenu", popup_panel)
	theme.set_color("font_color", "PopupMenu", TEXT_WHITE)
	theme.set_color("font_hover_color", "PopupMenu", ACCENT_GOLD)
	theme.set_color("font_accelerator_color", "PopupMenu", TEXT_GRAY)
	
	# HSlider
	var slider_grabber = StyleBoxFlat.new()
	slider_grabber.bg_color = ACCENT_GOLD
	slider_grabber.corner_radius_top_left = 8
	slider_grabber.corner_radius_top_right = 8
	slider_grabber.corner_radius_bottom_left = 8
	slider_grabber.corner_radius_bottom_right = 8
	
	var slider_bg = StyleBoxFlat.new()
	slider_bg.bg_color = BG_DARK
	slider_bg.corner_radius_top_left = 4
	slider_bg.corner_radius_top_right = 4
	slider_bg.corner_radius_bottom_left = 4
	slider_bg.corner_radius_bottom_right = 4
	
	theme.set_stylebox("grabber_area", "HSlider", progress_fill)
	theme.set_stylebox("grabber_area_highlight", "HSlider", progress_fill)
	theme.set_stylebox("slider", "HSlider", slider_bg)
	
	# Guardar tema
	var err = ResourceSaver.save(theme, "res://theme.tres")
	if err == OK:
		print("Tema guardado correctamente en theme.tres")
	else:
		print("Error guardando tema: ", err)
