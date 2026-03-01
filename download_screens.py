import os
import subprocess

screens = [
    {
        "name": "01_Dashboard",
        "img": "https://lh3.googleusercontent.com/aida/AOfcidWupgW70LF3XMJLtSUT6hSlLTtnHVCr13tfXtjUWLlsD3rMobljJRwd05q1kO6wCgRtD8FTswJ6j0KsWvqTlEp0pq5V1vm_WJX9rsQp45ciKzOix5nVwmvEHCIvTPAozQAx8ZG33KzEVdTB6Ee5i9lYTpYdVZkX42VZoYPViwoMCuvRFB4sR2zaJh2fIuzc9wm_3GccTPxxT26DkS78yQu2co3GqF78Rmkb6JLzRROJ-6njmgaPH98IbPU",
        "html": "https://contribution.usercontent.google.com/download?c=CgthaWRhX2NvZGVmeBJ7Eh1hcHBfY29tcGFuaW9uX2dlbmVyYXRlZF9maWxlcxpaCiVodG1sX2M4YjBiZDhmNzRlNTRkMzFhMTI4Nzc2ZDYzYjQxNjMzEgsSBxD7kfbRgxEYAZIBIwoKcHJvamVjdF9pZBIVQhM4NzA5MzMwOTg3MTk5MTUwNDg4&filename=&opi=89354086"
    },
    {
        "name": "02_Transaction_Feed",
        "img": "https://lh3.googleusercontent.com/aida/AOfcidWirIdxeSH1fDH5loUeMw4qzWAAXrwDBVRJIPit3pWe9ENRf5RfnygDmxDXZi2EdFQCdO7oZ9tJBsdhiTUjXILrOoStlxpn3aSprIHnE7lpZ1cIAav1zC0wS6WScnhBbd_4NwEwhNGsexYEoK6GBVeo5xxppmIGj7FppqXBMZHUb-ZdBh4T4y7LD4LEkAi20SCeB4CoNGZ9bkwHZwzbfRZ8XPBm-Z8MNICUbeV8OcdTePB69WuxkhD9ip4",
        "html": "https://contribution.usercontent.google.com/download?c=CgthaWRhX2NvZGVmeBJ7Eh1hcHBfY29tcGFuaW9uX2dlbmVyYXRlZF9maWxlcxpaCiVodG1sX2E3MDQ2Y2Q4OWI2ODQzZWNiZjBkOGY3NmEwY2Y5M2M4EgsSBxD7kfbRgxEYAZIBIwoKcHJvamVjdF9pZBIVQhM4NzA5MzMwOTg3MTk5MTUwNDg4&filename=&opi=89354086"
    },
    {
        "name": "03_Add_Expense",
        "img": "https://lh3.googleusercontent.com/aida/AOfcidXyOkKiqYxlHC-F_b3F_EpgOOnJRTsVjL94mmy3hWeOiv9wRZt1y_e0y0e1XWWlP5zvIJob1e4BpojlSE5Ozy-jnJNcW7-3J0LcF_q9Unj8xMzxw3q-YdN39dO-LYP4aiS6L8UvI9xvsBpWbcaxwGbDqZlmNPfEdF-Yy-BYBhhTkFI9SAi3I9OTTXDlsD0nzsyN3QwzvRu8Whxc38Rv10RiScqmCDeVqUXMXSZX-pPIdletnGrKumgWddY",
        "html": "https://contribution.usercontent.google.com/download?c=CgthaWRhX2NvZGVmeBJ7Eh1hcHBfY29tcGFuaW9uX2dlbmVyYXRlZF9maWxlcxpaCiVodG1sX2YzNWEzYjczNjg4NTRiNDA5NTUxN2JlOWM1OWZmZWIzEgsSBxD7kfbRgxEYAZIBIwoKcHJvamVjdF9pZBIVQhM4NzA5MzMwOTg3MTk5MTUwNDg4&filename=&opi=89354086"
    },
    {
        "name": "04_Transaction_Detail_and_Source_View",
        "img": "https://lh3.googleusercontent.com/aida/AOfcidWW2X54BTNcv1sT_RTSAWjKv1z5dayJ1fX_rsSBcFe8OkJRXr7mktZ8SmxCgt9_FU6qjmE6j_zX5iYIfwXHT-xdX1QSedxLl5VVTBOVinwjb7gm-AQdlLUh7t5nQEyeoP4GiyHjlT2-KIn3iGUf1EH1nwl8MuaV-BQWLmAvm7wa0b8weBuDj8SbTBxkp4P3XfAsJVAD1PJJmCEoAcHvktRnGMmqAjycVXolLPSYBhd537AI8iavuE2UaQ",
        "html": "https://contribution.usercontent.google.com/download?c=CgthaWRhX2NvZGVmeBJ7Eh1hcHBfY29tcGFuaW9uX2dlbmVyYXRlZF9maWxlcxpaCiVodG1sXzJjY2Q0NDE0ZTIyMTQ2ZTY4YjkzNWRkNTI4ZGJmMmExEgsSBxD7kfbRgxEYAZIBIwoKcHJvamVjdF9pZBIVQhM4NzA5MzMwOTg3MTk5MTUwNDg4&filename=&opi=89354086"
    },
    {
        "name": "05_Message_Inbox",
        "img": "https://lh3.googleusercontent.com/aida/AOfcidVZPzK_tlGCb4gZC_44fQlYSxx7vdeuc7_ZpCCCDzVM84eYQ80cuQBqMpnEJr49b9nDZzUca4rLGBduUa89IRRGVSDUNBBCutSXuT-LY7GiE4X3CeIneALJXwmLAHSQEqg11t582eqXl8wMDlXCIJUh0NBUg3X-7r_NO67pzecOz5lzowUeOcgIV0NWN9pkJxmpjryAz1JV3tKgvMb9cTLgMXYvx4xdG5Zne8Pi7JyIO665fl6NOmT6m_E",
        "html": "https://contribution.usercontent.google.com/download?c=CgthaWRhX2NvZGVmeBJ7Eh1hcHBfY29tcGFuaW9uX2dlbmVyYXRlZF9maWxlcxpaCiVodG1sXzAzOWQ3OTQxMTVlNDQ1NWVhOTVlYjY1ZTM5ZmJiZTgzEgsSBxD7kfbRgxEYAZIBIwoKcHJvamVjdF9pZBIVQhM4NzA5MzMwOTg3MTk5MTUwNDg4&filename=&opi=89354086"
    },
    {
        "name": "06_Ignored_Messages",
        "img": "https://lh3.googleusercontent.com/aida/AOfcidUXPhYRTJwSBMVKSN60ZQBwqG3oGZFelSakeiRXphUmlcSor8iR7PBvkJ0h1Zav338WAJvupDcnUoMMLaFJeTnUWIhw6S3GPQkuD1TfKz2G6XhTPhVQV-SU_R0a4Hxcy83_RYoeETGCsxhbu6CJm0MRpf9h3Dcjxc3qA3WNnUPDyeJIASMAd-7yXItLwGziZ3fpIvZXRzmr__EehCdJUKNloAQLPcbkAr_FgCptH7RBzDU4h1ohVE5P8g",
        "html": "https://contribution.usercontent.google.com/download?c=CgthaWRhX2NvZGVmeBJ7Eh1hcHBfY29tcGFuaW9uX2dlbmVyYXRlZF9maWxlcxpaCiVodG1sX2QwNWM3ZjZjYTIyZDRjZjI4OWYwMTRkZGM3NjZkMjJiEgsSBxD7kfbRgxEYAZIBIwoKcHJvamVjdF9pZBIVQhM4NzA5MzMwOTg3MTk5MTUwNDg4&filename=&opi=89354086"
    },
    {
        "name": "07_Settings_and_Data",
        "img": "https://lh3.googleusercontent.com/aida/AOfcidXVPLJ9JLYRasnRByJP48QqzNPzoXmntdCeClt7-MJuj5NQW4zJPWT7f1gRwjJ4tHwjlnBz3YZPatzGaom8nmA3eMd4m6mqciycsb5CSk_L-j4BzbiuW4PWd26yFgF56tM6DPMuJ2FM-9UaP3YDcl0WnSW-uiggeiuHB6P6eTobW1l37CW_L1EydOnyeLu4EN4D9fS1LLVuoEbkC2QvNfNYzrUpbGbaFFmBr0RRMPJjF9qiXJyaHZpUK9c",
        "html": "https://contribution.usercontent.google.com/download?c=CgthaWRhX2NvZGVmeBJ7Eh1hcHBfY29tcGFuaW9uX2dlbmVyYXRlZF9maWxlcxpaCiVodG1sX2RiYWE1N2IzNjliMDQyM2ZiNjhjMmM4M2M5OWMyY2RjEgsSBxD7kfbRgxEYAZIBIwoKcHJvamVjdF9pZBIVQhM4NzA5MzMwOTg3MTk5MTUwNDg4&filename=&opi=89354086"
    },
    {
        "name": "08_Link_Family_Members",
        "img": "https://lh3.googleusercontent.com/aida/AOfcidVTC475A2hcrZ9x7hWbYY2xzr22Qe-sNbvmHrYNAgTALv-LDCFbC2CIDrKJ0EYnYJhdfMmYqH87A16cqqbYpxJ-t8JKqTyXjQhqW_k_jmS7gTCfO7H-AV8zCDzwq876DdjJ8L34GKDdE5Iu-OPA4f0niIJgmEpETnl91viQj-z7Xp1Bt-luHv4Wh3dKUOjXQnJ_OMLqwD6tGQE7t7oYs_2rOdqm_eSJirJdTkTBIGDjqQJOnnbqNQD2Og",
        "html": "https://contribution.usercontent.google.com/download?c=CgthaWRhX2NvZGVmeBJ7Eh1hcHBfY29tcGFuaW9uX2dlbmVyYXRlZF9maWxlcxpaCiVodG1sXzdlZDgwNzFhOWQ3OTQ1M2ViZWI4MzdjNDVkODAyNzE0EgsSBxD7kfbRgxEYAZIBIwoKcHJvamVjdF9pZBIVQhM4NzA5MzMwOTg3MTk5MTUwNDg4&filename=&opi=89354086"
    },
    {
        "name": "09_Monthly_Budget_Planning",
        "img": "https://lh3.googleusercontent.com/aida/AOfcidWPDlx_fLQgymYU7FMJV0M5leP08-0cao3Kj7SmHzyLX5TLMpfeQbArRSnrmvBcU2ZycwV70Z5fkhtK991Muodia2UVwHuk0nCm5ZdJcW3qq-44Bwz3tNKomfeWx_39I3iCGB1A5NZqX71j-J3xAsv_M791bBirUgrHQw-FcRHfsAGTdQSLZQVXGOCHmlrnKt--sPgRfs56x-QkHncaroozyWwaepWBbVtog_QivInzg8fbuCwtMUi-4wI",
        "html": "https://contribution.usercontent.google.com/download?c=CgthaWRhX2NvZGVmeBJ7Eh1hcHBfY29tcGFuaW9uX2dlbmVyYXRlZF9maWxlcxpaCiVodG1sXzQ3NDBkNDdmY2JmNDRkOWE4YjY2ZGQ0MGM3OGViMzQ5EgsSBxD7kfbRgxEYAZIBIwoKcHJvamVjdF9pZBIVQhM4NzA5MzMwOTg3MTk5MTUwNDg4&filename=&opi=89354086"
    },
    {
        "name": "10_Family_Group_Settings",
        "img": "https://lh3.googleusercontent.com/aida/AOfcidVO_e_j9KwXnW6XVkpmA3qoXApUUT0Y6M59PIzkP9hG0EUR3zfC9t-I0fmee_x_LeZO_pu7QyFg3XkqmLTiEpOM0bduCivwOjMal-PRWVQ-SOCFRk-93YEI_mC4E2WgTau6T1KT84Nn6lwCsftl804MC2kiTEjy-L4KLpTip3B_VAkRSkK5YblIA1hUeZF47mxaMCrm5R6VXxDW4-_RfVdy-abA6ZlFPahv9DFBBm5A17oNTESNwuXCmg",
        "html": "https://contribution.usercontent.google.com/download?c=CgthaWRhX2NvZGVmeBJ7Eh1hcHBfY29tcGFuaW9uX2dlbmVyYXRlZF9maWxlcxpaCiVodG1sXzljYWVjY2E2MzhlOTRlZGI4MWRiODM3OGIzMGFjZjhlEgsSBxD7kfbRgxEYAZIBIwoKcHJvamVjdF9pZBIVQhM4NzA5MzMwOTg3MTk5MTUwNDg4&filename=&opi=89354086"
    }
]

out_dir = "d:/git/budgetly/stitch_screens"
os.makedirs(out_dir, exist_ok=True)

for screen in screens:
    img_path = os.path.join(out_dir, f"{screen['name']}.png")
    html_path = os.path.join(out_dir, f"{screen['name']}.html")
    
    print(f"Downloading {screen['name']}...")
    subprocess.run(["curl.exe", "-s", "-L", screen['img'], "-o", img_path])
    subprocess.run(["curl.exe", "-s", "-L", screen['html'], "-o", html_path])

print("Done downloading all screens.")
