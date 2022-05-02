import FindMarketTenant from "../contracts/FindMarketTenant.cdc"
import FlowToken from "../contracts/standard/FlowToken.cdc"
import Dandy from "../contracts/Dandy.cdc"
import FindMarketSale from "../contracts/FindMarketSale.cdc"
import FindMarketAuctionEscrow from "../contracts/FindMarketAuctionEscrow.cdc"
import FindMarketAuctionSoft from "../contracts/FindMarketAuctionSoft.cdc"
import FindMarketDirectOfferEscrow from "../contracts/FindMarketDirectOfferEscrow.cdc"
import FindMarketDirectOfferSoft from "../contracts/FindMarketDirectOfferSoft.cdc"


transaction(market: String){
    prepare(account: AuthAccount){
        let path = FindMarketTenant.TenantClientStoragePath
        let tenantRef = account.borrow<&FindMarketTenant.TenantClient>(from: path) ?? panic("Cannot borrow Reference.")

        var marketType : [Type] = [Type<@FindMarketSale.SaleItem>()]
        switch market {
            case "AuctionEscrow" :
                marketType = [Type<@FindMarketAuctionEscrow.SaleItem>()]

            case "AuctionSoft" :
                marketType = [Type<@FindMarketAuctionSoft.SaleItem>()]

            case "DirectOfferEscrow" :
                marketType = [Type<@FindMarketDirectOfferEscrow.SaleItem>()]

            case "DirectOfferSoft" :
                marketType = [Type<@FindMarketDirectOfferSoft.SaleItem>()]

        }

        tenantRef.setMarketOption(name:"FlowDandy".concat(market), cut: nil, rules:[
            FindMarketTenant.TenantRule(name:"Flow", types:[Type<@FlowToken.Vault>()], ruleType: "ft", allow: true),
            FindMarketTenant.TenantRule(name:"Dandy", types:[Type<@Dandy.NFT>()], ruleType: "nft", allow: true),
            FindMarketTenant.TenantRule(name: market, types:marketType, ruleType: "listing", allow: true)
            ]
        )
    }
}
