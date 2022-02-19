local aws_v4 = require "kong.plugins.aws.v4"
local request_util = require "kong.plugins.aws.request-util"

local plugin = {
  VERSION = "1.0.0",
  PRIORITY = 10,
}

function plugin:access(plugin_conf)

  local incoming_headers = ngx.req.get_headers()
  local headers = {}

  -- Sign the request using the `Host` without
  -- a port, as this is what Kong uses.
  -- headers["host"] = ngx.var.host
  --headers["host"] = "rekognition.us-east-1.amazonaws.com"
  headers["host"] = string.format("rekognition.%s.amazonaws.com", plugin_conf.aws_region)

  -- Proxy the content headers only as they are AWS requirements.
  -- They are also likely the only headers to remain consistent
  -- between Client -> Kong -> AWS.
  headers["content-length"] = incoming_headers["content-length"]
  headers["content-type"] = incoming_headers["content-type"]
  headers["X-Amz-Target"] = incoming_headers["X-Amz-Target"]

  local body_data = request_util.read_request_body(false)

  local opts = {
    region = plugin_conf.aws_region,
    service = plugin_conf.aws_service,
    access_key = plugin_conf.aws_key,
    secret_key = plugin_conf.aws_secret,
    body = body_data,
    canonical_querystring = ngx.var.args,
    headers = headers,
    method = ngx.req.get_method(),
    path = string.gsub(ngx.var.upstream_uri, "^https?://[a-z0-9.-]+", ""),
    port = ngx.var.port,
  }

  local request, err = aws_v4(opts)
  if err then
    kong.log.err(err)
    return kong.response.exit(500, "Internal Server Error")
  end

  for key, val in pairs(request.headers) do
    ngx.req.set_header(key, val)
  end

  -- Use the same `Host` as the one used
  -- for signing the request.
  ngx.var.upstream_host = request.host
end

return plugin
