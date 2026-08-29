# task_runner.gd
# The single async mechanism: run blocking Callables on worker threads and
# marshal their results back to the main thread. No other code should spawn raw
# Threads or block the main thread on I/O.

class_name TaskRunner
extends Node

signal task_completed(result)

const MAX_THREADS := 16

var _pending: Dictionary = {}  # Thread -> on_done Callable
var _queue: Array = []         # [{action, on_done}] waiting for a free slot


## Run a blocking callable in a background thread; on_done(result) fires on the
## main thread. If the bound object is freed before completion, on_done is dropped.
func run(action: Callable, on_done: Callable) -> void:
	if _pending.size() >= MAX_THREADS:
		_queue.append({"action": action, "on_done": on_done})
		return
	_start_thread(action, on_done)


func _start_thread(action: Callable, on_done: Callable) -> void:
	var thread := Thread.new()
	var err := thread.start(action)
	if err != OK:
		push_error("TaskRunner: thread start failed (%d)" % err)
		on_done.call(null)
		return
	_pending[thread] = on_done


func _process(_delta: float) -> void:
	if not _pending.is_empty():
		var done: Array = []
		for thread in _pending.keys():
			if not thread.is_alive():
				done.append(thread)
		for thread in done:
			var result = thread.wait_to_finish()
			var on_done: Callable = _pending[thread]
			_pending.erase(thread)
			if on_done.is_valid():
				on_done.call(result)
			task_completed.emit(result)
	# Drain queued work now that slots may be free.
	while _pending.size() < MAX_THREADS and not _queue.is_empty():
		var task: Dictionary = _queue.pop_front()
		_start_thread(task["action"], task["on_done"])


func _exit_tree() -> void:
	for thread in _pending.keys():
		if thread.is_alive():
			thread.wait_to_finish()
	_pending.clear()
	_queue.clear()
