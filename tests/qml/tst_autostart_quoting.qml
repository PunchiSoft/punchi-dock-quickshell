// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtTest
import "../../services/PunchiAutostartEntry.js" as Entry

TestCase {
    id: test
    name: "AutostartQuoting"

    function test_execQuoteEscapesControlCharacters() {
        const newline = Entry.execQuote("a\nb")
        compare(newline.indexOf("\n"), -1)
        verify(newline.indexOf("\\n") >= 0)
        const carriage = Entry.execQuote("a\rb")
        compare(carriage.indexOf("\r"), -1)
        verify(carriage.indexOf("\\r") >= 0)
    }

    function test_execQuoteEscapesFieldAndShellCharacters() {
        const quoted = Entry.execQuote("a$b%c`d\"e\\f")
        verify(quoted.indexOf("\\$") >= 0)
        verify(quoted.indexOf("%%") >= 0)
        verify(quoted.indexOf("\\`") >= 0)
        verify(quoted.indexOf("\\\"") >= 0)
        verify(quoted.indexOf("\\\\") >= 0)
    }

    function test_valueQuoteKeepsPercentLiteral() {
        compare(Entry.valueQuote("/tmp/100%/icon.svg"), "\"/tmp/100%/icon.svg\"")
        const newline = Entry.valueQuote("a\nb")
        compare(newline.indexOf("\n"), -1)
        verify(newline.indexOf("\\n") >= 0)
    }
}
