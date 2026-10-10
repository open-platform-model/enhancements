// Package record makes the small edits the writing tasks do to an entry:
// a top-level key of config.yaml, a line of tasks.md, the sampled line of
// source.md. The edits are text edits, so comments and order stay as written.
package record

import (
	"bytes"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"strings"

	"gopkg.in/yaml.v3"

	"github.com/open-platform-model/enhancements/tools/enh/internal/words"
)

// Quote writes s as a double-quoted YAML scalar (JSON strings are valid YAML).
func Quote(s string) string {
	var b bytes.Buffer
	enc := json.NewEncoder(&b)
	enc.SetEscapeHTML(false)
	_ = enc.Encode(s) // a string always encodes
	return strings.TrimRight(b.String(), "\n")
}

// Edit replaces or adds one top-level key. Block is the whole text of the key
// with its value, for example "status: accepted" or a mapping with indented
// lines. A trailing newline is optional.
type Edit struct {
	Key   string
	Block string
}

// SetKeys applies the edits to the text of a YAML mapping and checks that the
// result still parses. A key that exists keeps its place; a new key goes to
// the end of the file.
func SetKeys(src string, edits ...Edit) (string, error) {
	out := src
	for _, e := range edits {
		if !keyRe.MatchString(e.Key + ":") {
			return "", fmt.Errorf("record: %q is not a plain key", e.Key)
		}
		out = setKey(out, e.Key, strings.TrimRight(e.Block, "\n")+"\n")
	}
	var probe map[string]any
	if err := yaml.Unmarshal([]byte(out), &probe); err != nil {
		return "", fmt.Errorf("record: the edited file is not valid YAML: %w", err)
	}
	return out, nil
}

var keyRe = regexp.MustCompile(`^[A-Za-z_][A-Za-z0-9_]*:`)

func setKey(src, key, block string) string {
	lines := strings.SplitAfter(src, "\n")
	if n := len(lines); n > 0 && lines[n-1] == "" {
		lines = lines[:n-1]
	}
	start := -1
	for i, l := range lines {
		if strings.HasPrefix(l, key+":") {
			start = i
			break
		}
	}
	if start < 0 {
		out := strings.Join(lines, "")
		if out != "" && !strings.HasSuffix(out, "\n") {
			out += "\n"
		}
		return out + block
	}
	end := start + 1
	for end < len(lines) {
		l := lines[end]
		if l == "\n" || l == "" || strings.HasPrefix(l, " ") || strings.HasPrefix(l, "\t") || strings.HasPrefix(l, "- ") || l == "-\n" {
			end++
			continue
		}
		break
	}
	// Blank lines that end the value belong to the gap before the next key.
	for end > start+1 && strings.TrimSpace(lines[end-1]) == "" {
		end--
	}
	var b strings.Builder
	b.WriteString(strings.Join(lines[:start], ""))
	b.WriteString(block)
	b.WriteString(strings.Join(lines[end:], ""))
	return b.String()
}

var taskTickRe = regexp.MustCompile(`^- \[ \] (\d+\.\d+) (.+?)\s*$`)
var taskDoneRe = regexp.MustCompile(`^- \[[xX]\] (\d+\.\d+) `)

// Tick errors.
var (
	ErrTicked  = errors.New("task line is already ticked")
	ErrNoLine  = errors.New("no such task line")
	ErrBadLine = errors.New("task line number must read n.m")
)

var lineNumRe = regexp.MustCompile(`^\d+\.\d+$`)

// Tick ticks the line "n.m" of tasks.md text and appends "(ref)". The line
// must be open. A line inside a code fence is not a task.
func Tick(src, num, ref string) (string, error) {
	if !lineNumRe.MatchString(num) {
		return "", fmt.Errorf("%w: %q", ErrBadLine, num)
	}
	lines := strings.Split(src, "\n")
	mask := words.FenceMask(lines)
	for i, l := range lines {
		if mask[i] {
			continue
		}
		if m := taskDoneRe.FindStringSubmatch(l); m != nil && m[1] == num {
			return "", fmt.Errorf("%w: %s", ErrTicked, num)
		}
		if m := taskTickRe.FindStringSubmatch(l); m != nil && m[1] == num {
			lines[i] = "- [x] " + num + " " + m[2] + " (" + ref + ")"
			return strings.Join(lines, "\n"), nil
		}
	}
	return "", fmt.Errorf("%w: %s", ErrNoLine, num)
}

var sampledRe = regexp.MustCompile(`(?m)^sampled:.*\n?`)

// SetSampled writes the sampled line of source.md as its last line. It removes
// every earlier line that starts with "sampled:", the placeholder of the
// template included.
func SetSampled(src, value string) string {
	out := sampledRe.ReplaceAllString(src, "")
	out = strings.TrimRight(out, "\n") + "\n\n"
	return out + "sampled: " + value + "\n"
}

// WriteFile replaces path with data: it writes a temporary file in the same
// folder, syncs it and renames it over the target.
func WriteFile(path string, data []byte) (err error) {
	mode := os.FileMode(0o644)
	if fi, serr := os.Stat(path); serr == nil {
		mode = fi.Mode().Perm()
	}
	f, err := os.CreateTemp(filepath.Dir(path), ".enh-*")
	if err != nil {
		return err
	}
	name := f.Name()
	defer func() {
		if err != nil {
			_ = os.Remove(name) // best effort: the write already failed
		}
	}()
	if _, err = f.Write(data); err != nil {
		_ = f.Close() // the write error is the one to report
		return err
	}
	if err = f.Sync(); err != nil {
		_ = f.Close() // the sync error is the one to report
		return err
	}
	if err = f.Close(); err != nil {
		return err
	}
	if err = os.Chmod(name, mode); err != nil {
		return err
	}
	return os.Rename(name, path)
}
