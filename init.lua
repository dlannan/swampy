
-- "A web dyno must bind to its assigned $PORT within 60 seconds of startup."
-- see https://devcenter.heroku.com/articles/dynos#web-dynos
local port = process.env["PORT"] or 5000
local httpsserver = require("app.httpsserver")
httpsserver.run(port)

