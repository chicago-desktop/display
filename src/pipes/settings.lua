local app = require("app")
local repo = require("repo")
local options = require("options")
local definition = {close_on_escape=true}
function definition.init(): any
    local store = repo.of(repo.person())
    local saved, err = store.setting(options.KEY)
    return {values=options.read(saved),failure=err and tostring(err) or nil,
        persist=function(value) return store.set_setting(options.KEY,value) end}
end
function definition.view(state: any, context: any): any
    local children = {}
    for _, key in ipairs({"speed","thickness","palette"}) do
        children[#children+1] = {kind="group",title=string.upper(string.sub(key,1,1)) .. string.sub(key,2),size=3,size_px=58,
            children={{kind="select",id=key,value=state.values[key],options=options.choices[key]}}}
    end
    children[#children+1] = {kind="label",text=state.failure or "Settings apply to the next Preview.",wrap=true,alert=state.failure~=nil}
    children[#children+1] = {kind="row",size=2,size_px=30,gap=1,gap_px=6,align="right",children={
        {kind="button",id="ok",text="OK",size=10,size_px=81,width_px=75,default=true},
        {kind="button",id="cancel",text="Cancel",size=10,size_px=81,width_px=75}}}
    return {kind="column",padding=1,padding_px=7,gap=0,children=children}
end
function definition.update(state: any, action: any, context: any)
    if action.type=="change" and options.valid(action.id,action.value) then state.values[action.id]=action.value
    elseif action.type=="activate" and action.id=="ok" then
        local _, err=state.persist(options.encode(state.values))
        if err then state.failure=tostring(err) else context.close() end
    elseif action.type=="activate" and action.id=="cancel" then context.close()
    else return false end
end
return {definition=definition,main=app.main(definition)}
