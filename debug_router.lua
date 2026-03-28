package.path = './src/?.lua;./?.lua;./tests/?.lua;' .. package.path
local router_v2 = require('router_v2')

router_v2.clear()

local function dummy_handler() end

-- Test: Register /users, match /posts (should NOT match) 
router_v2.get('/users', dummy_handler)

local debug_routes = router_v2.debug_routes()
print("Registered routes:")
for method, routes in pairs(debug_routes) do
  for i, route in ipairs(routes) do
    print("  " .. method .. " " .. route.pattern)
  end
end

print("\nAttempting to match GET /posts:")
local handler, err, params = router_v2.match('GET', '/posts')
print("Handler found: " .. tostring(handler ~= nil))
print("Error: " .. tostring(err))

-- Now let's test if GET /users matches correctly  
print("\nAttempting to match GET /users:")
local handler2, err2, params2 = router_v2.match('GET', '/users')
print("Handler found: " .. tostring(handler2 ~= nil))
print("Error: " .. tostring(err2))

print("\n--- Testing pattern matching ---")
print("Direct Lua pattern test:")
local p1 = "/users"
local p2 = "/posts"
local pat = "^/users$"

local m1 = table.pack(p1:match(pat))
local m2 = table.pack(p2:match(pat))

print("  '" .. p1 .. "':match('" .. pat .. "') = " .. m1.n .. " matches")
print("  '" .. p2 .. "':match('" .. pat .. "') = " .. m2.n .. " matches")

-- Check what Nika's compile_pattern generates  
local routes_get = router_v2.get_routes("GET")
if routes_get[1] then
    print("\nRoute internal details:")
    print("  pattern field:", routes_get[1].pattern)
    print("  lua_pattern field:", routes_get[1].lua_pattern)
    print("  param_names count:", #routes_get[1].param_names)
end

print("\n--- Testing before_each behavior ---")
router_v2.clear()
print("After clear, count:", router_v2.count())
