// Copied verbatim from enhancements/0001/schemas/target.cue at the time
// of writing (see Setup). Skill rule: copy, never reference. If target.cue's
// #FQNType evolves, this copy goes stale on purpose — re-copy when re-running.
package schema

#FQNType: string &
	=~"^[a-z0-9.-]+(/[a-z0-9.-]+)*/[a-z0-9]([a-z0-9-]*[a-z0-9])?@\\d+\\.\\d+\\.\\d+(-[0-9A-Za-z-]+(\\.[0-9A-Za-z-]+)*)?(\\+[0-9A-Za-z-]+(\\.[0-9A-Za-z-]+)*)?$"
