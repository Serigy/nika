local M = {}

--- Escape for HTML text content (general-purpose).
function M.escape_html_text(value)
    local str = tostring(value or "")
    str = str:gsub("&", "&amp;")
    str = str:gsub("<", "&lt;")
    str = str:gsub(">", "&gt;")
    str = str:gsub('"', "&quot;")
    str = str:gsub("'", "&#39;")
    return str
end

--- Escape for HTML attribute values (quoted).
function M.escape_html_attr(value)
    local str = tostring(value or "")
    str = str:gsub("&", "&amp;")
    str = str:gsub("<", "&lt;")
    str = str:gsub(">", "&gt;")
    str = str:gsub('"', "&quot;")
    str = str:gsub("'", "&#39;")
    return str
end

--- Escape for URL attribute values (href, src, etc).
-- Whitelist safe schemes and encode unreserved characters.
function M.escape_url_attr(value)
    local str = tostring(value or "")

    local normalized = str:gsub("^%s+", ""):lower()

    if normalized:find("javascript:", 1, true) == 1 then
        return ""
    end
    if normalized:find("data:", 1, true) == 1 then
        return ""
    end

    local safe_schemes = { http = true, https = true, mailto = true, ftp = true, ["//"] = true, ["/"] = true }
    local scheme = normalized:match("^([a-z][a-z0-9+.-]*):") or (normalized:find("^/", 1, true) and "/" or nil)

    if scheme and not safe_schemes[scheme] then
        return ""
    end

    str = str:gsub("&", "&amp;")
    str = str:gsub("<", "&lt;")
    str = str:gsub(">", "&gt;")
    str = str:gsub('"', "&quot;")
    str = str:gsub("'", "&#39;")

    return str
end

--- Escape for JavaScript string context (not yet fully supported).
function M.escape_js_string(value)
    local str = tostring(value or "")

    str = str:gsub("\\", "\\\\")
    str = str:gsub('"', '\\"')
    str = str:gsub("'", "\\'")
    str = str:gsub("\r", "\\r")
    str = str:gsub("\n", "\\n")
    str = str:gsub("\t", "\\t")

    return str
end

--- Escape for CSS string context (not yet fully supported).
function M.escape_css_string(value)
    local str = tostring(value or "")

    str = str:gsub("\\", "\\\\")
    str = str:gsub('"', '\\"')
    str = str:gsub("'", "\\'")
    str = str:gsub("\r", "\\r")
    str = str:gsub("\n", "\\n")

    return str
end

--- Dispatch escape function by context name.
function M.escape_by_context(context_name, value)
    if context_name == "HTML_TEXT" then
        return M.escape_html_text(value)
    elseif context_name == "HTML_ATTR_QUOTED" then
        return M.escape_html_attr(value)
    elseif context_name == "URL_ATTR" then
        return M.escape_url_attr(value)
    elseif context_name == "JS_STRING" then
        return M.escape_js_string(value)
    elseif context_name == "CSS_STRING" then
        return M.escape_css_string(value)
    else
        return M.escape_html_text(value)
    end
end

return M
