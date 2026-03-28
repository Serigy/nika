local json_util = require("json_util")

local M = {}

local function split_accept_header(header)
    local items = {}
    for token in tostring(header or ""):gmatch("[^,]+") do
        local media = token:match("^%s*([^;]+)")
        if media then
            items[#items + 1] = string.lower((media:gsub("%s+", "")))
        end
    end
    return items
end

local function has_media(items, media)
    for i = 1, #items do
        if items[i] == media then
            return true
        end
    end
    return false
end

local function escape_html(value)
    local str = tostring(value or "")
    str = str:gsub("&", "&amp;")
    str = str:gsub("<", "&lt;")
    str = str:gsub(">", "&gt;")
    str = str:gsub('"', "&quot;")
    str = str:gsub("'", "&#39;")
    return str
end

local function escape_xml(value)
    local str = tostring(value or "")
    str = str:gsub("&", "&amp;")
    str = str:gsub("<", "&lt;")
    str = str:gsub(">", "&gt;")
    str = str:gsub('"', "&quot;")
    str = str:gsub("'", "&apos;")
    return str
end

function M.negotiate(accept_header, default_format)
    local accepted = split_accept_header(accept_header)
    local fallback = default_format or "json"

    if has_media(accepted, "application/json") then
        return "json"
    end
    if has_media(accepted, "application/xml") or has_media(accepted, "text/xml") then
        return "xml"
    end
    if has_media(accepted, "text/html") then
        return "html"
    end

    if has_media(accepted, "application/*") then
        return "json"
    end
    if has_media(accepted, "text/*") then
        return "html"
    end
    if has_media(accepted, "*/*") then
        return fallback
    end

    return fallback
end

function M.render(payload, format)
    local safe_payload = payload or {}
    local target = format or "json"

    if target == "xml" then
        local body = table.concat({
            "<?xml version=\"1.0\" encoding=\"UTF-8\"?>",
            "<error>",
            "<status>" .. escape_xml(safe_payload.status) .. "</status>",
            "<code>" .. escape_xml(safe_payload.error) .. "</code>",
            "<message>" .. escape_xml(safe_payload.message) .. "</message>",
            "</error>"
        })
        return body, "application/xml; charset=utf-8"
    end

    if target == "html" then
        local body = table.concat({
            "<html><head><title>Error</title></head><body>",
            "<h1>" .. escape_html(safe_payload.status) .. "</h1>",
            "<p>" .. escape_html(safe_payload.message) .. "</p>",
            "</body></html>"
        })
        return body, "text/html; charset=utf-8"
    end

    return json_util.encode(safe_payload), "application/json; charset=utf-8"
end

return M
