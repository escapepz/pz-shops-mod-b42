local oldIsValid = ISInventoryTransferAction.isValid
function ISInventoryTransferAction:isValid()
    local valid = oldIsValid(self)
    
    -- No additional validation needed if srcContainer is not a player shop
    if not self.srcContainer then return valid end
    
    local parent = self.srcContainer:getParent()
    if not parent then return valid end
    
    -- If container has owner modData, validate ownership
    local parentModData = parent:getModData()
    if parentModData and parentModData.owner then
        local username = self.character:getUsername()
        local isOwner = (username == parentModData.owner)
        
        -- Allow admin override
        if isAdmin() then
            isOwner = true
        end
        
        return (valid and isOwner)
    end
    
    -- No owner restriction, allow transfer
    return valid
end