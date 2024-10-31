local sqlite = require("lsqlite3")
local json = require("json")
DBClient = DBClient or sqlite.open_memory()

local initSQL = [[
INSERT INTO temp.lembed_models(name, model) 
    select 'all-MiniLM-L6-v2', lembed_model_from_file('/data/M-OzkyjxWhSvWYF87p0kvmkuAEEkvOzIj4nMNoSIydc');
select lembed(
    'all-MiniLM-L6-v2',
    'The United States Postal Service is an independent agency...'
);
create table articles(
    headline text
);

-- Build a vector table with embeddings of article headlines
create virtual table vec_articles using vec0(
    headline_embeddings float[1600]
);
]]

Handlers.add("Init", "Init", function (msg)
    local execResult = DBClient:exec(initSQL)
    if execResult ~= 0 then
        msg.reply({ Status = "500", Data = "Failed to initialize database"})
        return
    end
    msg.reply({ Status = "200", Data = "Database initialized"})
end)

local function createInsertSQL(articles)
    assert(type(articles) == "table", "articles must be a table")
    assert(#articles > 0, "articles must not be empty")
    local insertSQL = ""
    for i, article in ipairs(articles) do
      if i == 1 then
        insertSQL = insertSQL .. "insert into articles VALUES ('" .. article .. "')"
      else
        insertSQL = insertSQL .. ", ('" .. article .. "')"
      end
    end
    insertSQL = insertSQL .. ";"
    return insertSQL
end

-- currently only supports one time embedding because of the way the table insert into vec_articles.
Handlers.add("Embedding", "Embedding", function (msg)
    local insertSQL = createInsertSQL(json.decode(msg.Data))
    insertSQL = insertSQL .. [[
insert into vec_articles(rowid, headline_embeddings)
    select rowid, lembed('all-MiniLM-L6-v2', headline) from articles;
]]
    local execResult = DBClient:exec(insertSQL)
    if execResult ~= 0 then
        msg.reply({ Status = "500", Data = "Failed to embed articles"})
        return
    end
    msg.reply({ Status = "200", Data = "Articles embedded"})
end)

Handlers.add("Retrieve", "Retrieve", function (msg)
    assert(msg.Data, "Data is required")
    local data = json.decode(msg.Data)
    assert(data.prompt, "prompt is required")
    assert(data.limit, "limit is required")
    local query = [[
with matches as (
    select
        rowid,
        distance
    from vec_articles
    where headline_embeddings match lembed('all-MiniLM-L6-v2', ']] .. data.prompt .. [[')
    order by distance
    limit ]] .. data.limit .. [[
)
select
    headline,
    distance
from matches
    left join articles on articles.rowid = matches.rowid;
]]
    local result = {}
    for row in DBClient:nrows(query) do
        table.insert(result, row)
    end
    msg.reply({ Status = "200", Data = json.encode(result)})
end)