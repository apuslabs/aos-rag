import { describe, it } from 'node:test'
import assert from 'assert'
import weaveDrive from './weavedrive.js'
import fs from 'fs'
const wasm = fs.readFileSync('./process.wasm')
// STEP 1 send a file id
import m from "./process.js"

const AdmissableList =
  [
    "dx3GrOQPV5Mwc1c-4HTsyq0s1TNugMf7XfIKJkyVQt8", // Random NFT metadata (1.7kb of JSON)
    "XOJ8FBxa6sGLwChnxhF2L71WkKLSKq1aU5Yn5WnFLrY", // GPT-2 117M model.
    "M-OzkyjxWhSvWYF87p0kvmkuAEEkvOzIj4nMNoSIydc", // GPT-2-XL 4-bit quantized model.
    "kd34P4974oqZf2Db-hFTUiCipsU6CzbR6t-iJoQhKIo", // Phi-2 
    "ISrbGzQot05rs_HKC08O_SmkipYQnqgB1yC3mjZZeEo", // Phi-3 Mini 4k Instruct
    "sKqjvBbhqKvgzZT4ojP1FNvt4r_30cqjuIIQIr-3088", // CodeQwen 1.5 7B Chat q3
    "Pr2YVrxd7VwNdg6ekC0NXWNKXxJbfTlHhhlrKbAd1dA", // Llama3 8B Instruct q4
    "jbx-H6aq7b3BbNCHlK50Jz9L-6pz9qmldrYXMwjqQVI"  // Llama3 8B Instruct q8
  ]


const InsertModelSQL = `
  INSERT INTO temp.lembed_models(name, model) select 'all-MiniLM-L6-v2', lembed_model_from_file('/data/st');
  select lembed(
    'all-MiniLM-L6-v2',
    'The United States Postal Service is an independent agency...'
  );
  `
  
const CreateAritclesSQL = `
  create table articles(
    headline text
  );
  
  -- Random NPR headlines from 2024-06-04
  insert into articles VALUES
    ('Shohei Ohtani''s ex-interpreter pleads guilty to charges related to gambling and theft'),
    ('The jury has been selected in Hunter Biden''s gun trial'),
    ('Larry Allen, a Super Bowl champion and famed Dallas Cowboy, has died at age 52'),
    ('After saying Charlotte, a lone stingray, was pregnant, aquarium now says she''s sick'),
    ('An Epoch Times executive is facing money laundering charge');
  `
  
const EmbeddingSQL = `
  -- Build a vector table with embeddings of article headlines
  create virtual table vec_articles using vec0(
    headline_embeddings float[384]
  );
  
  insert into vec_articles(rowid, headline_embeddings)
    select rowid, lembed('all-MiniLM-L6-v2', headline)
    from articles;
  `
  
const RetrieveSQL = `
  with matches as (
  select
      rowid,
      distance
  from vec_articles
  where headline_embeddings match lembed('all-MiniLM-L6-v2', 'firearm courtroom')
  order by distance
  limit 3
  )
  select
  headline,
  distance
  from matches
  left join articles on articles.rowid = matches.rowid;
  `

describe('AOS-Sqlite-vec Tests', async () => {
  var instance;

  const handle = async function (msg, env) {
    const res = await instance.cwrap('handle', 'string', ['string', 'string'], { async: true })(JSON.stringify(msg), JSON.stringify(env))
    console.log('Memory used:', instance.HEAP8.length)
    return JSON.parse(res)
  }

  it('Create instance', async () => {
    console.log("Creating instance...")
    var instantiateWasm = function (imports, cb) {

      // merge imports argument
      const customImports = {
        env: {
          memory: new WebAssembly.Memory({ initial: 8589934592 / 65536, maximum: 17179869184 / 65536, index: 'i64' })
        }
      }
      //imports.env = Object.assign({}, imports.env, customImports.env)

      WebAssembly.instantiate(wasm, imports).then(result =>

        cb(result.instance)
      )
      return {}
    }

    instance = await m({
      admissableList: AdmissableList,
      WeaveDrive: weaveDrive,
      // ARWEAVE: 'https://arweave.net/',
      ARWEAVE: 'http://localhost:3000/',
      mode: "test",
      blockHeight: 100,
      spawn: {
        "Scheduler": "TEST_SCHED_ADDR"
      },
      process: {
        id: "TEST_PROCESS_ID",
        owner: "TEST_PROCESS_OWNER",
        tags: [
          { name: "Extension", value: "Weave-Drive" }
        ]
      },
      instantiateWasm
    })
    await instance['FS_createPath']('/', 'data')
    await instance['FS_createDataFile']('/', 'data/1', Buffer.from('HELLO WORLD'), true, false, false)
    await new Promise((r) => setTimeout(r, 1000));
    console.log("Instance created.")
    await new Promise((r) => setTimeout(r, 250));

    assert.ok(instance)
  })

  it('Insert models', async () => {
    const SelectSQL = `
local select = [[${RetrieveSQL}]]
local result = {}
for row in DBClient:nrows(select) do
  table.insert(result, row)
end
return json.encode(result)
`
    const result = await handle(getEval(`
local sqlite = require("lsqlite3")
local json = require("json")
DBClient = sqlite.open_memory()
local database = [[${InsertModelSQL}${CreateAritclesSQL}${EmbeddingSQL}]]
local execResult = DBClient:exec(database)
print(execResult)
if execResult == 0 then
${SelectSQL}
end
    `), getEnv())
    console.log(result)
    const data = JSON.parse(result.response.Output.data.substring(2))
    assert(data.length >= 1)
  })
})

function getEval(expr) {
  return {
    Target: 'AOS',
    From: 'FOOBAR',
    Owner: 'FOOBAR',

    Module: 'FOO',
    Id: '1',

    'Block-Height': '1000',
    Timestamp: Date.now(),
    Tags: [
      { name: 'Action', value: 'Eval' }
    ],
    Data: expr
  }
}

function getEnv() {
  return {
    Process: {
      Id: 'AOS',
      Owner: 'FOOBAR',

      Tags: [
        { name: 'Name', value: 'TEST_PROCESS_OWNER' }
      ]
    }
  }
}