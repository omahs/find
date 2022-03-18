package main

import (
	"fmt"

	"github.com/bjartek/overflow/overflow"
)

func main() {

	//o := overflow.NewOverflowEmulator().Start()
	o := overflow.NewOverflowInMemoryEmulator().Start()

	//first step create the adminClient as the fin user
	o.TransactionFromFile("setup_fin_1_create_client").
		SignProposeAndPayAs("find").
		RunPrintEventsFull()

	//link in the server in the versus client
	o.TransactionFromFile("setup_fin_2_register_client").
		SignProposeAndPayAsService().
		Args(o.Arguments().Account("find")).
		RunPrintEventsFull()

	//set up fin network as the fin user
	o.TransactionFromFile("setup_fin_3_create_network").
		SignProposeAndPayAs("find").
		RunPrintEventsFull()

	o.TransactionFromFile("setup_find_market_1").
		SignProposeAndPayAsService().
		RunPrintEventsFull()

	//link in the server in the versus client
	o.TransactionFromFile("setup_find_market_2").
		SignProposeAndPayAs("find").
		Args(o.Arguments().Account("account").Boolean(true).Boolean(false)). //test with non escrow
		RunPrintEventsFull()

	//we advance the clock
	o.TransactionFromFile("clock").SignProposeAndPayAs("find").
		Args(o.Arguments().UFix64(1.0)).
		RunPrintEventsFull()

	o.TransactionFromFile("createProfile").
		SignProposeAndPayAsService().
		Args(o.Arguments().String("find")).
		RunPrintEventsFull()

	o.TransactionFromFile("createProfile").
		SignProposeAndPayAs("user1").
		Args(o.Arguments().String("User1")).
		RunPrintEventsFull()

	o.TransactionFromFile("createProfile").
		SignProposeAndPayAs("user2").
		Args(o.Arguments().String("User2")).
		RunPrintEventsFull()

	o.TransactionFromFile("createProfile").
		SignProposeAndPayAs("find").
		Args(o.Arguments().String("Find")).
		RunPrintEventsFull()

	o.TransactionFromFile("mintFusd").
		SignProposeAndPayAsService().
		Args(o.Arguments().Account("user1").UFix64(100.0)).
		RunPrintEventsFull()

	o.TransactionFromFile("register").
		SignProposeAndPayAs("user1").
		Args(o.Arguments().String("user1").UFix64(5.0)).
		RunPrintEventsFull()

	o.TransactionFromFile("mintFusd").
		SignProposeAndPayAsService().
		Args(o.Arguments().Account("user2").UFix64(100.0)).
		RunPrintEventsFull()

	o.TransactionFromFile("register").
		SignProposeAndPayAs("user2").
		Args(o.Arguments().String("alice").UFix64(5.0)).
		RunPrintEventsFull()

	o.TransactionFromFile("mintFusd").
		SignProposeAndPayAsService().
		Args(o.Arguments().Account("user2").UFix64(100.0)).
		RunPrintEventsFull()

	o.TransactionFromFile("mintFlow").
		SignProposeAndPayAsService().
		Args(o.Arguments().Account("user2").UFix64(100.0)).
		RunPrintEventsFull()

	o.TransactionFromFile("buyAddon").SignProposeAndPayAs("user1").
		Args(o.Arguments().String("user1").String("forge").UFix64(50.0)).
		RunPrintEventsFull()

	id := o.TransactionFromFile("mintDandy").
		SignProposeAndPayAs("user1").
		Args(o.Arguments().
			String("user1").
			UInt64(3).
			String("Neo").
			String("Neo Motorcycle").
			String(`Bringing the motorcycle world into the 21st century with cutting edge EV technology and advanced performance in a great classic British style, all here in the UK`).
			String("https://neomotorcycles.co.uk/assets/img/neo_motorcycle_side.webp")).
		RunGetIdFromEventPrintAll("A.f8d6e0586b0a20c7.Dandy.Minted", "id")

		//	o.SimpleTxArgs("listDandyForSale", "user1", o.Arguments().UInt64(id).UFix64(10.0))

	o.SimpleTxArgs("listDandyForAuction", "user1", o.Arguments().UInt64(id).UFix64(10.0))
	res := o.ScriptFromFile("listSaleItems").Args(o.Arguments().Account("user1")).RunReturnsJsonString()
	fmt.Println(res)

	o.SimpleTxArgs("bidMarket", "user2", o.Arguments().Account("user1").UInt64(id).UFix64(15.0))

	res2 := o.ScriptFromFile("listSaleItems").Args(o.Arguments().Account("user1")).RunReturnsJsonString()
	fmt.Println(res2)

	o.SimpleTxArgs("clock", "find", o.Arguments().UFix64(400.0))

	//o.SimpleTxArgs("fulfillMarketAuction", "user2", o.Arguments().Account("user1").UInt64(id))
	o.SimpleTxArgs("fulfillMarketAuctionNotEscrowed", "user2", o.Arguments().Account("user1").UInt64(id).UFix64(15.0))
	/*

		o.SimpleTxArgs("listDandyForSale", "user1", o.Arguments().UInt64(id).UFix64(10.0))
		o.ScriptFromFile("dandyViews").Args(o.Arguments().String("user1").UInt64(id)).Run()
		o.ScriptFromFile("dandy").Args(o.Arguments().String("user1").UInt64(id).String("A.f8d6e0586b0a20c7.MetadataViews.Display")).Run()

		o.SimpleTxArgs("bidMarket", "user2", o.Arguments().Account("user1").UInt64(id).UFix64(10.0).Account("account"))

		/*

			res := o.ScriptFromFile("listSaleItems").Args(o.Arguments().Account("user1")).RunReturnsJsonString()
			fmt.Println(res)

				o.SimpleTxArgs("bidMarket", "user1", o.Arguments().Account("user2").UInt64(id).UFix64(15.0))

				res = o.ScriptFromFile("listSaleItems").Args(o.Arguments().Account("user2")).RunReturnsJsonString()
				fmt.Println(res)

					o.SimpleTxArgs("clock", "find", o.Arguments().UFix64(400.0))

					o.SimpleTxArgs("fulfillMarketAuction", "user1", o.Arguments().Account("user2").UInt64(id))

					o.SimpleTxArgs("bidMarket", "user2", o.Arguments().Account("user1").UInt64(id).UFix64(10.0))

					o.SimpleTxArgs("fulfillMarketDirectOffer", "user1", o.Arguments().UInt64(id))

					o.SimpleTxArgs("listDandyForSale", "user2", o.Arguments().UInt64(id).UFix64(10.0))
					o.SimpleTxArgs("bidMarket", "user1", o.Arguments().Account("user2").UInt64(id).UFix64(5.0))
					o.SimpleTxArgs("increasebidMarket", "user1", o.Arguments().UInt64(id).UFix64(5.0))
	*/

}