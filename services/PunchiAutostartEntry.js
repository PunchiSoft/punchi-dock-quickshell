// SPDX-License-Identifier: GPL-3.0-or-later
.pragma library

// Desktop-entry quoting kept pure so it can be tested without the Quickshell
// runtime. `execQuote` also defends the Exec value: `%` is a field code there
// and the shell metacharacters are escaped. `valueQuote` is for plain values
// such as Icon=, where `%` is literal.
function execQuote(value) {
    return "\"" + String(value)
        .replace(/\\/g, "\\\\")
        .replace(/"/g, "\\\"")
        .replace(/`/g, "\\`")
        .replace(/\$/g, "\\$")
        .replace(/%/g, "%%")
        .replace(/\r/g, "\\r")
        .replace(/\n/g, "\\n") + "\""
}

function valueQuote(value) {
    return "\"" + String(value)
        .replace(/\\/g, "\\\\")
        .replace(/"/g, "\\\"")
        .replace(/\r/g, "\\r")
        .replace(/\n/g, "\\n") + "\""
}
