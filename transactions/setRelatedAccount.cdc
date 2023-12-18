import FindRelatedAccounts from "../contracts/FindRelatedAccounts.cdc"
import FIND from "../contracts/FIND.cdc"

transaction(name: String, target: String) {

    var relatedAccounts : &FindRelatedAccounts.Accounts?
    let address : Address?

    prepare(account: auth(SaveValue) &Account) {


        self.address = FIND.resolve(target)

        self.relatedAccounts= account.storage.borrow<&FindRelatedAccounts.Accounts>(from:FindRelatedAccounts.storagePath)
        if self.relatedAccounts == nil {
            let relatedAccounts <- FindRelatedAccounts.createEmptyAccounts()
            account.save(<- relatedAccounts, to: FindRelatedAccounts.storagePath)

            let cap = account.capabilities.storage.issue<&{FindRelatedAccounts.Public}>(FindRelatedAccounts.storagePath)
            account.capabilities.publish(cap, at: FindRelatedAccounts.publicPath)
            self.relatedAccounts= account.storage.borrow<&FindRelatedAccounts.Accounts>(from:FindRelatedAccounts.storagePath)
        }

        let cap = account.capabilities.get<&{FindRelatedAccounts.Public}>(FindRelatedAccounts.publicPath)
        if cap == nil {
            account.unlink(FindRelatedAccounts.publicPath)
            let cap = account.capabilities.storage.issue<&{FindRelatedAccounts.Public}>(FindRelatedAccounts.storagePath)
            account.capabilities.publish(cap, at: FindRelatedAccounts.publicPath)
        }
    }

    pre{
        self.address != nil : "The input pass in is not a valid name or address. Input : ".concat(target)
    }

    execute{
        self.relatedAccounts!.addFlowAccount(name: name, address: self.address!)
    }
}
