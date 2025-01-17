import FIND from "../contracts/FIND.cdc"
import FUSD from "../contracts/standard/FUSD.cdc"
import FindMarket from "../contracts/FindMarket.cdc"
import Clock from "../contracts/Clock.cdc"

pub struct FINDReport{

    pub let leases: [FIND.LeaseInformation]
    pub let leasesBids: [FIND.BidInfo]
    pub let itemsForSale: {String : FindMarket.SaleItemCollectionReport}
    pub let marketBids: {String : FindMarket.BidItemCollectionReport}

    init(
        bids: [FIND.BidInfo],
        leases : [FIND.LeaseInformation],
        leasesBids: [FIND.BidInfo],
        itemsForSale: {String : FindMarket.SaleItemCollectionReport},
        marketBids: {String : FindMarket.BidItemCollectionReport},
    ) {

        self.leases=leases
        self.leasesBids=leasesBids
        self.itemsForSale=itemsForSale
        self.marketBids=marketBids
    }
}


pub fun main(user: String) : FINDReport? {

    let maybeAddress=FIND.resolve(user)
    if maybeAddress == nil{
        return nil
    }

    let address=maybeAddress!

    let account=getAuthAccount(address)
    if account.balance == 0.0 {
        return nil
    }

    let leaseCap = account.getCapability<&FIND.LeaseCollection{FIND.LeaseCollectionPublic}>(FIND.LeasePublicPath)
    let leases = leaseCap.borrow()?.getLeaseInformation() ?? []
    /*
    let bidCap = account.getCapability<&FIND.BidCollection{FIND.BidCollectionPublic}>(FIND.BidPublicPath)

    let oldLeaseBid = bidCap.borrow()?.getBids() ?? []
    */

    let find= FindMarket.getFindTenantAddress()
    var items : {String : FindMarket.SaleItemCollectionReport} = FindMarket.getSaleItemReport(tenant:find, address: address, getNFTInfo:true)
    var marketBids : {String : FindMarket.BidItemCollectionReport} = FindMarket.getBidsReport(tenant:find, address: address, getNFTInfo:true)

    return FINDReport(
        bids: [],
        leases: leases,
        leasesBids: [],
        itemsForSale: items,
        marketBids: marketBids,
    )
}



