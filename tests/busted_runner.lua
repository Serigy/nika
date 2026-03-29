local busted = require("tests.busted_lite")

local SPEC_MODULES = {
    "tests.integration_mvp_spec",
    "tests.security_regression_spec",
    "tests.determinism_spec",
    "tests.template_functions_registry_spec",
    "tests.template_partials_spec",
    "tests.template_text_mode_spec",
    "tests.template_equivalence_spec",
    "tests.template_pentest_final_spec",
    -- Phase 10: Route/Middleware/Context
    "tests.context_store_spec",
    "tests.middleware_chain_spec",
    "tests.router_v2_spec",
    "tests.route_group_spec",
    -- Phase 11: Dataware ORM + Auto-CRUD
    "tests.dataware_spec",
    "tests.dataware_audit_spec",
    "tests.dataware_tenancy_spec",
    "tests.db_transaction_spec",
    "tests.query_builder_spec",
    "tests.auto_crud_spec",
    "tests.sqlite_driver_spec",
    "tests.sqlite_dataware_integration_spec",
    -- Phase 14: Validation + Binding + Security middleware
    "tests.validator_spec",
    "tests.binder_spec",
    "tests.security_middleware_spec",
    -- Phase 12: File upload foundation
    "tests.multipart_spec",
    "tests.file_validator_spec",
    "tests.file_storage_spec",
    "tests.file_manager_spec",
    "tests.adapter_cgi_multipart_spec",
    "tests.nika_upload_flow_spec",
    -- Phase 13: Error handling
    "tests.error_formatter_spec",
    "tests.error_handler_spec",
    "tests.nika_error_flow_spec",
    -- Phase 13 Block 3: Robustness
    "tests.nika_middleware_error_flow_spec",
    "tests.nika_stress_errors_spec"
}

local function run_suite(suite)
    local failures = 0

    io.write("\n" .. suite.name .. "\n")

    for i = 1, #suite.tests do
        local test = suite.tests[i]

        if suite.before_each then
            local ok_before, before_err = pcall(suite.before_each)
            if not ok_before then
                io.write("  [FAIL] " .. test.name .. " (before_each): " .. tostring(before_err) .. "\n")
                failures = failures + 1
                goto continue
            end
        end

        local ok_test, test_err = pcall(test.fn)
        if not ok_test then
            io.write("  [FAIL] " .. test.name .. ": " .. tostring(test_err) .. "\n")
            failures = failures + 1
        else
            io.write("  [OK] " .. test.name .. "\n")
        end

        if suite.after_each then
            local ok_after, after_err = pcall(suite.after_each)
            if not ok_after then
                io.write("  [FAIL] " .. test.name .. " (after_each): " .. tostring(after_err) .. "\n")
                failures = failures + 1
            end
        end

        ::continue::
    end

    return failures
end

local function run_all()
    busted.reset()
    local restore = busted.install_globals()

    local load_failures = 0
    for i = 1, #SPEC_MODULES do
        local mod = SPEC_MODULES[i]
        local ok, err = pcall(require, mod)
        if not ok then
            io.write("[FAIL] load spec " .. mod .. ": " .. tostring(err) .. "\n")
            load_failures = load_failures + 1
        end
    end

    if load_failures > 0 then
        restore()
        io.write("TOTAL FAILURES: " .. tostring(load_failures) .. "\n")
        return false
    end

    local suites = busted.get_suites()
    local failures = 0

    for i = 1, #suites do
        failures = failures + run_suite(suites[i])
    end

    if failures > 0 then
        restore()
        io.write("\nTOTAL FAILURES: " .. tostring(failures) .. "\n")
        return false
    end

    restore()
    io.write("\nALL SPECS PASSED\n")
    return true
end

return {
    run = run_all
}
