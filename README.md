# aos-rag

1. Load Demo Code

```
.load process/rag.lua
```

1. Init Model & Vec DB

```
Send({ Target = ao.id, Action = "Init" })
```

Message received should be `Database initialized`

3. Embedding Data
```
Send({ Target = ao.id, Action = 'Embedding', Data = '["Shohei Ohtanis ex-interpreter pleads guilty to charges related to gambling and theft","The jury has been selected in Hunter Bidens gun trial","Larry Allen, a Super Bowl champion and famed Dallas Cowboy, has died at age 52","After saying Charlotte, a lone stingray, was pregnant, aquarium now says shes sick","An Epoch Times executive is facing money laundering charge"]' })
```

Message received should be `Articles embedded`

4. Retrieve
```
Send({ Target = ao.id, Action = "Retrieve", Data = '{"prompt":"firearm courtroom","limit":3}' })
```

Message received should be in JSON of sorted list contains `headline` & `distance`, distance represents how much headline is similarity with your prompt.
