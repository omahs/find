package main

import (
	"encoding/csv"
	"encoding/json"
	"fmt"
	"log"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/bjartek/go-with-the-flow/v2/gwtf"
)

func main() {
	file, ok := os.LookupEnv("file")
	if !ok {
		fmt.Println("file is not present")
		os.Exit(1)
	}

	flowverse, ok := os.LookupEnv("flowverse")
	if !ok {
		fmt.Println("file is not present")
		os.Exit(1)
	}
	g := gwtf.NewGoWithTheFlowMainNet()

	reservedNames := readNameAddresses(file)
	flowverseNames := readCsvFile(flowverse)

	go forever(g, reservedNames, flowverseNames)

	quitChannel := make(chan os.Signal, 1)
	signal.Notify(quitChannel, syscall.SIGINT, syscall.SIGTERM)
	<-quitChannel
	//time for cleanup before exit
	fmt.Println("Adios!")
}

func forever(g *gwtf.GoWithTheFlow, reservedNames map[string]string, flowverseNames map[string]string) {
	for {

		result := g.ScriptFromFile("reserveStatus").AccountArgument("find-admin").RunReturnsJsonString()
		var bids []LeaseBids
		err := json.Unmarshal([]byte(result), &bids)
		if err != nil {
			panic(err)
		}

		for _, bid := range bids {
			_, exist := flowverseNames[bid.Name]
			if exist {
				fmt.Printf("Name is in flovwerse list %s\n", bid.Name)
				g.TransactionFromFile("rejectDirectOffer").SignProposeAndPayAs("find-admin").StringArgument(bid.Name).RunPrintEventsFull()
				continue
			}

			reservedAddress, exist := reservedNames[bid.Name]
			if !exist {
				fmt.Printf("Name is not reserved %s\n", bid.Name)
				continue
			}

			//			fmt.Printf("Bid %s, reserved %s", bid.LatestBidBy, reservedAddress)
			if bid.LatestBidBy == reservedAddress && bid.LatestBid == bid.Cost {
				fmt.Printf("Fullfilled bid %v\n", bid)
				g.TransactionFromFile("fulfill").SignProposeAndPayAs("find-admin").StringArgument(bid.Name).RunPrintEventsFull()
			} else {
				fmt.Printf("Rejected offer on name=%s from bidder=%s\n", bid.Name, bid.LatestBidBy)
				g.TransactionFromFile("rejectDirectOffer").SignProposeAndPayAs("find-admin").StringArgument(bid.Name).RunPrintEventsFull()
			}
		}

		time.Sleep(20 * time.Second)
	}
}

type LeaseBids struct {
	Address     string `json:"address"`
	Cost        string `json:"cost"`
	LatestBid   string `json:"latestBid"`
	LatestBidBy string `json:"latestBidBy"`
	Name        string `json:"name"`
	Status      string `json:"status"`
}

func readNameAddresses(filePath string) map[string]string {
	f, err := os.Open(filePath)
	if err != nil {
		log.Fatal("Unable to read input file "+filePath, err)
	}
	defer f.Close()

	csvReader := csv.NewReader(f)
	records, err := csvReader.ReadAll()

	if err != nil {
		log.Fatal("Unable to parse file as CSV for "+filePath, err)
	}

	results := map[string]string{}
	for i, row := range records {
		if i == 0 {
			continue
		}
		results[row[3]] = row[2]
	}

	return results
}

func readCsvFile(filePath string) map[string]string {
	f, err := os.Open(filePath)
	if err != nil {
		log.Fatal("Unable to read input file "+filePath, err)
	}
	defer f.Close()

	csvReader := csv.NewReader(f)
	records, err := csvReader.ReadAll()

	if err != nil {
		log.Fatal("Unable to parse file as CSV for "+filePath, err)
	}

	results := map[string]string{}
	for i, row := range records {
		if i == 0 {
			continue
		}
		results[row[0]] = row[0]
	}

	return results
}