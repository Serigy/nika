local M = {}

local URL_ATTRS = {
    href = true,
    src = true,
    action = true,
    formaction = true,
    poster = true,
    cite = true,
    data = true,
    srcset = true
}

local function trim(s)
    return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function last_pattern_index(str, pattern)
    local cursor = 1
    local last

    while true do
        local i = string.find(str, pattern, cursor)
        if not i then
            break
        end
        last = i
        cursor = i + 1
    end

    return last
end

local function infer_expr_context(template_source, open_start, literal_before)
    local prefix = string.sub(template_source, 1, open_start - 1):lower()
    local last_script_open = last_pattern_index(prefix, "<script[%s>]")
    local last_script_close = last_pattern_index(prefix, "</script>")
    if last_script_open and (not last_script_close or last_script_open > last_script_close) then
        return "JS_STRING"
    end

    local last_style_open = last_pattern_index(prefix, "<style[%s>]")
    local last_style_close = last_pattern_index(prefix, "</style>")
    if last_style_open and (not last_style_close or last_style_open > last_style_close) then
        return "CSS_STRING"
    end

    local lower_literal = literal_before:lower()
    local attr_name = lower_literal:match("([%w_:%-]+)%s*=%s*['\"]%s*$")
    if attr_name then
        if URL_ATTRS[attr_name] then
            return "URL_ATTR"
        end
        return "HTML_ATTR_QUOTED"
    end

    return "HTML_TEXT"
end

local function compile_tokens(template)
    local lines = {}
    local cursor = 1
    local contexts = {}

    lines[#lines + 1] = "local __buf = {}"
    lines[#lines + 1] = "local function __nika_write(v) table.insert(__buf, tostring(v)) end"
    lines[#lines + 1] = "local escape = assert(escape, \"escape function is required\")"
    lines[#lines + 1] =
    "local __nika_escape_by_context = assert(__nika_escape_by_context, \"__nika_escape_by_context function is required\")"
    lines[#lines + 1] = "local __nika_partial = assert(__nika_partial, \"__nika_partial function is required\")"
    lines[#lines + 1] = "local function write(_) error(\"blocked_context:RAW_TEXT_TEMPLATE\", 2) end"
    lines[#lines + 1] = "local function partial(name, data) return __nika_partial(name, data) end"
    lines[#lines + 1] = "local function include(name, data) __nika_write(__nika_partial(name, data)) end"
    lines[#lines + 1] = "local function __nika_emit(context, value)"
    lines[#lines + 1] = "  local raw = tostring(value or \"\")"
    lines[#lines + 1] = "  __nika_write(__nika_escape_by_context(context, raw))"
    lines[#lines + 1] = "end"

    while true do
        local open_start, open_end = string.find(template, "<%", cursor, true)

        if not open_start then
            local literal = string.sub(template, cursor)
            if literal ~= "" then
                lines[#lines + 1] = "__nika_write(" .. string.format("%q", literal) .. ")"
            end
            break
        end

        local literal = string.sub(template, cursor, open_start - 1)
        if literal ~= "" then
            lines[#lines + 1] = "__nika_write(" .. string.format("%q", literal) .. ")"
        end

        local close_start, _ = string.find(template, "%>", open_end + 1, true)
        if not close_start then
            return nil, "Template invalido: tag <% sem fechamento %>"
        end

        local raw_block = string.sub(template, open_end + 1, close_start - 1)
        local left_trimmed = raw_block:gsub("^%s+", "")

        if string.sub(left_trimmed, 1, 1) == "=" then
            local expr = trim(string.sub(left_trimmed, 2))
            if expr == "" then
                return nil, "Template invalido: bloco <%= %> vazio"
            end
            local context_name = infer_expr_context(template, open_start, literal)
            contexts[#contexts + 1] = context_name
            lines[#lines + 1] = "__nika_emit(\"" .. context_name .. "\", " .. expr .. ")"
        else
            local code = trim(raw_block)
            if code ~= "" then
                lines[#lines + 1] = code
            end
        end

        cursor = close_start + 2
    end

    lines[#lines + 1] = "return table.concat(__buf)"

    return table.concat(lines, "\n"), {
        contexts = contexts
    }
end

function M.compile(template_source)
    if type(template_source) ~= "string" then
        return nil, "Template invalido: esperado string"
    end

    return compile_tokens(template_source)
end

return M
