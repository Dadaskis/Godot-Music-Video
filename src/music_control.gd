extends Node

const VU_COUNT = 32
const FREQ_MAX = 4500.0
const MIN_DB = 80

export(Array, Resource) var data_array

var started = false
var spectrum
var data: MusicData
var data_index = 0
var energy_array = []
var timer: float = 0.0
var timer_complete: float = 0.0

onready var waves_list = $Waves
onready var audio_player = $AudioPlayer
onready var image = $Image
onready var dark_blend = $DarkBlend
onready var track_length = $TrackLength
onready var track_length_current = $TrackLength/Current
onready var length_text_target = $LengthTextTarget
onready var length_text_current = $LengthTextCurrent

func set_label_text_time(label: Label, time: float):
	var minutes = floor(time / 60.0)
	var minutes_text = str(minutes)
	if minutes < 10:
		minutes_text = "0" + minutes_text
	
	var seconds = int(time) % 60
	var seconds_text = str(seconds)
	if seconds < 10:
		seconds_text = "0" + seconds_text
	
	label.text = minutes_text + ":" + seconds_text

func process_new_music():
	print("Playing music: " + str(data_index))
	if data_index >= len(data_array):
		started = false
		return
	data = data_array[data_index]
	data_index += 1
	audio_player.stream = data.sample
	audio_player.play()
	image.texture = data.image
	timer = 0.0
	timer_complete = data.sample.get_length()
	
	set_label_text_time(length_text_target, timer_complete)

func _ready():
	spectrum = AudioServer.get_bus_effect_instance(0, 0)
	
	var temp0 = waves_list.get_node("0")
	energy_array.append(0)
	for counter in range(31):
		var temp_dupe = temp0.duplicate()
		waves_list.add_child(temp_dupe)
		energy_array.append(0)
	
	audio_player.connect("finished", self, "process_new_music")

func _physics_process(delta):
	if timer < timer_complete - 10.0:
		dark_blend.color.a = lerp(
			dark_blend.color.a,
			0.0,
			0.5 * delta
		)
	else:
		dark_blend.color.a = lerp(
			dark_blend.color.a,
			1.0,
			0.5 * delta
		)
	
	if not started:
		return
	
	timer += delta
	
	var index = 0
	var prev_hz = 0
	for value in waves_list.get_children():
		var waveform = value as ColorRect
		waveform.rect_scale.y = rand_range(0.0, -1.0)
		
		var hz = index * FREQ_MAX / VU_COUNT;
		var magnitude: float = \
			spectrum.get_magnitude_for_frequency_range(prev_hz, hz).length()
		var energy = clamp((MIN_DB + linear2db(magnitude)) / MIN_DB, 0, 1)
		prev_hz = hz
		energy += 0.01
		
		var prev_energy = energy_array[index]
		energy = lerp(prev_energy, energy, 8.0 * delta)
		energy_array[index] = energy
		
		waveform.rect_scale.y = -energy
		
		index += 1
	
	if timer_complete > 0.0:
		var current_track_pos: = float(timer) / float(timer_complete)
		var track_pixel_length = track_length.rect_size.x
		track_length_current.rect_position.x = lerp(
			0.0,
			track_pixel_length,
			current_track_pos
		)
		
		set_label_text_time(length_text_current, timer)

func _input(event):
	if started:
		return
	if Input.is_action_just_pressed("start_key"):
		process_new_music()
		started = true
