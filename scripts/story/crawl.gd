class_name Crawl
extends Resource
# The story crawl on the title: why you are playing, rolling up from PRESS
# START and away towards the logo. Text and pacing are data.

## Paragraphs separated by blank lines. A paragraph in capitals is a heading.
@export_multiline var text := ""
## Seconds before the first line appears.
@export var start_delay := 1.5
## Text pixels per second.
@export var speed := 42.0
## Seconds of empty sky between the last line leaving and the crawl starting over.
@export var loop_pause := 6.0
