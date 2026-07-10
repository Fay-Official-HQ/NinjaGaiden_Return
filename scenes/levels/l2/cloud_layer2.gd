extends ParallaxLayer

@onready var _tilemap: TileMapLayer = $TileMapLayer
@onready var _tilemap2: TileMapLayer = $TileMapLayer2

var _offset: float = 0.0
var _offset2: float = 0.0

const TILE_WIDTH: float = 512.0


func _process(delta: float) -> void:
	_offset += 10.0 * delta
	_offset2 += 20.0 * delta

	_tilemap.position.x = -fmod(_offset, TILE_WIDTH)
	_tilemap2.position.x = -fmod(_offset2, TILE_WIDTH)
