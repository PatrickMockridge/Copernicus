# navigation_model.gd
# The route graph + current destination. Pure logic, headless-testable.
# The activity bar, tab bar, and command palette all drive this one model.

class_name NavigationModel
extends RefCounted

signal route_changed(from_id: String, to_id: String)

## Loop-ordered sections; the activity bar/tab bar group routes by this order.
const SECTION_ORDER := ["design", "test", "publish", "operate", "utility", "manual"]

var _routes: Dictionary = {}  # id -> Route
var current_id: String = ""
var _history: Array = []      # back stack (ids)


func register(route: Route) -> void:
	_routes[route.id] = route


func get_route(id: String) -> Route:
	return _routes.get(id)


func navigate(id: String) -> bool:
	if not _routes.has(id):
		return false
	if current_id == id:
		return true
	var from := current_id
	if not from.is_empty():
		_history.append(from)
	current_id = id
	route_changed.emit(from, id)
	return true


func back() -> bool:
	if _history.is_empty():
		return false
	var prev: String = _history.pop_back()
	var from := current_id
	current_id = prev
	route_changed.emit(from, prev)
	return true


## The back-stack ids, oldest → newest (a copy).
func history() -> Array:
	return _history.duplicate()


## The breadcrumb trail: history routes then the current route (oldest → current).
func breadcrumb() -> Array:
	var out: Array = []
	for id in _history:
		if _routes.has(id):
			out.append(_routes[id])
	if _routes.has(current_id):
		out.append(_routes[current_id])
	return out


func current() -> Route:
	return _routes.get(current_id)


## Ordered, deduped section names (registration order).
func sections() -> Array:
	var out: Array = []
	for id in _order():
		var r: Route = _routes[id]
		if not out.has(r.section):
			out.append(r.section)
	return out


func routes_in_section(section: String) -> Array:
	var out: Array = []
	for id in _order():
		var r: Route = _routes[id]
		if r.section == section:
			out.append(r)
	return out


## All routes ordered by (section order, route order).
func ordered_routes() -> Array:
	var out: Array = []
	for id in _order():
		out.append(_routes[id])
	return out


func resolve_command(command_id: String) -> Route:
	for id in _routes:
		var r: Route = _routes[id]
		if r.command_id == command_id:
			return r
	return null


func _order() -> Array:
	var ids: Array = _routes.keys()
	ids.sort_custom(func(a, b) -> bool:
		var ra: Route = _routes[a]
		var rb: Route = _routes[b]
		var ra_s := _section_rank(ra.section)
		var rb_s := _section_rank(rb.section)
		if ra_s != rb_s:
			return ra_s < rb_s
		return ra.order < rb.order
	)
	return ids


func _section_rank(section: String) -> int:
	var idx := SECTION_ORDER.find(section)
	return SECTION_ORDER.size() if idx == -1 else idx
