local helpers = require "spec.helpers"

describe("kong health", function()
  setup(function()
    helpers.prepare_prefix()
  end)
  after_each(function()
    helpers.kill_all()
  end)

  it("health help", function()
    local _, stderr = helpers.kong_exec "health --help"
    assert.not_equal("", stderr)
  end)
  it("succeeds when Kong is running with custom --prefix", function()
    assert(helpers.kong_exec("start --conf "..helpers.test_conf_path))
    helpers.wait_until_running(
      helpers.test_conf.nginx_pid,
      helpers.test_conf.serf_pid
    )

    local _, _, stdout = assert(helpers.kong_exec("health --prefix "..helpers.test_conf.prefix))
    assert.matches("serf%.-running", stdout)
    assert.matches("nginx%.-running", stdout)
    assert.not_matches("dnsmasq.*running", stdout)
    assert.matches("Kong is healthy at " .. helpers.test_conf.prefix, stdout, nil, true)
  end)
  it("fails when Kong is not running", function()
    local ok, stderr = helpers.kong_exec("health --prefix " .. helpers.test_conf.prefix)
    assert.False(ok)
    assert.matches("Kong is not running at "..helpers.test_conf.prefix, stderr, nil, true)
  end)
  it("fails when a service is not running", function()
    assert(helpers.kong_exec("start --conf " .. helpers.test_conf_path))
    helpers.execute("pkill serf")

    local ok, stderr = helpers.kong_exec("health --prefix "..helpers.test_conf.prefix)
    assert.False(ok)
    assert.matches("some services are not running", stderr, nil, true)
  end)
  it("checks dnsmasq if enabled", function()
    assert(helpers.kong_exec("start --conf "..helpers.test_conf_path))
    helpers.wait_until_running(
      helpers.test_conf.nginx_pid,
      helpers.test_conf.serf_pid
    )

    local ok, stderr = helpers.kong_exec("health --prefix "..helpers.test_conf.prefix, {
      dnsmasq = true,
      dns_resolver = ""
    })
    assert.False(ok)
    assert.matches("some services are not running", stderr, nil, true)
  end)

  describe("errors", function()
    it("errors on inexisting prefix", function()
      local ok, stderr = helpers.kong_exec("health --prefix inexistant")
      assert.False(ok)
      assert.matches("no such prefix: ", stderr, nil, true)
    end)
  end)
end)
