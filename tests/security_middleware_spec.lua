local middleware_cors = require("middleware_cors")
local middleware_csrf = require("middleware_csrf")
local middleware_ratelimit = require("middleware_ratelimit")

describe("Security middlewares (Phase 14)", function()
    it("CORS responde preflight e faz short-circuit", function()
        local cors = middleware_cors.create({
            allowed_origins = { "https://app.example.com" }
        })

        local req = {
            method = "OPTIONS",
            headers = {
                origin = "https://app.example.com"
            }
        }
        local res = { status = 200, headers = {}, body = "x" }

        local short = cors(req, res, {})

        assert.is_true(short == true)
        assert.are.equal(204, res.status)
        assert.are.equal("", res.body)
        assert.are.equal("https://app.example.com", res.headers["Access-Control-Allow-Origin"])
    end)

    it("CORS bloqueia origin fora da allow-list", function()
        local cors = middleware_cors.create({
            allowed_origins = { "https://app.example.com" }
        })

        local req = {
            method = "GET",
            headers = {
                origin = "https://evil.example.com"
            }
        }
        local res = { status = 200, headers = {}, body = "" }

        local short = cors(req, res, {})

        assert.is_true(short == true)
        assert.are.equal(403, res.status)
        assert.is_true(res.body:find('"code":"cors_origin_not_allowed"', 1, true) ~= nil)
        assert.is_true(res.body:find('"retryable":false', 1, true) ~= nil)
    end)

    it("CSRF permite metodos de leitura sem token", function()
        local csrf = middleware_csrf.create({})
        local req = { method = "GET", headers = {} }
        local res = { status = 200, headers = {}, body = "" }

        local short = csrf(req, res, {})
        assert.is_true(short == false)
    end)

    it("CSRF bloqueia metodo mutavel sem cookie/header validos", function()
        local csrf = middleware_csrf.create({
            cookie_name = "csrf_token",
            header_name = "X-CSRF-Token"
        })

        local req = {
            method = "POST",
            headers = {
                ["cookie"] = "csrf_token=abc"
            }
        }
        local res = { status = 200, headers = {}, body = "" }

        local short = csrf(req, res, {})

        assert.is_true(short == true)
        assert.are.equal(403, res.status)
        assert.is_true(res.body:find('"code":"csrf_token_invalid"', 1, true) ~= nil)
    end)

    it("CSRF aceita token valido em cookie e header", function()
        local csrf = middleware_csrf.create({
            cookie_name = "csrf_token",
            header_name = "X-CSRF-Token",
            min_token_length = 4
        })

        local req = {
            method = "PUT",
            headers = {
                ["cookie"] = "csrf_token=token-seguro",
                ["X-CSRF-Token"] = "token-seguro"
            }
        }
        local res = { status = 200, headers = {}, body = "" }

        local short = csrf(req, res, {})
        assert.is_true(short == false)
    end)

    it("Rate-limit retorna 429 com Retry-After", function()
        local rate = middleware_ratelimit.create({
            window_seconds = 60,
            max_requests = 2
        })

        local req = {
            method = "GET",
            headers = {
                ["x-forwarded-for"] = "10.0.0.1"
            }
        }
        local res1 = { status = 200, headers = {}, body = "" }
        local res2 = { status = 200, headers = {}, body = "" }
        local res3 = { status = 200, headers = {}, body = "" }

        assert.is_true(rate(req, res1, {}) == false)
        assert.is_true(rate(req, res2, {}) == false)

        local short = rate(req, res3, {})

        assert.is_true(short == true)
        assert.are.equal(429, res3.status)
        assert.is_not_nil(res3.headers["Retry-After"])
        assert.is_true(res3.body:find('"code":"rate_limit_exceeded"', 1, true) ~= nil)
        assert.is_true(res3.body:find('"retryable":true', 1, true) ~= nil)
    end)
end)
