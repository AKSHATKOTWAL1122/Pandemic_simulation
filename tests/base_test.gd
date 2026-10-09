class_name BaseTest
extends RefCounted
## Base for test files. Each method starting with "test_" is one test.

var failures: Array[String] = []


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
