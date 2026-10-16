class_name SnapshotCodec
extends RefCounted


## JSON lê números como float. Snapshots de gameplay só contêm números inteiros.
## Restaura a representação antes de ressimular; jamais arredonda posições visuais.
static func integers(value: Variant) -> Variant:
	if value is float:
		return int(value)
	if value is Array:
		var result: Array = []
		for item in value:
			result.append(integers(item))
		return result
	if value is Dictionary:
		var result: Dictionary = {}
		for key in value:
			result[key] = integers(value[key])
		return result
	return value


static func state_hash(snapshot: Dictionary) -> String:
	# JSON can reorder dictionaries on reload. Sorted keys make hashes independent
	# of insertion order; all authoritative integers remain below 2^53.
	return JSON.stringify(snapshot, "", true).sha256_text()
