import FindVerifier from "../contracts/FindVerifier.cdc"

access(all) main(user: Address, findNames: [String]) : Result {
    let verifier = FindVerifier.HasFINDName(findNames)
    let input : {String : AnyStruct} = {"address" : user}
    return Result(verifier, input: input)
}

pub struct Result{
    access(all) let result : Bool 
    access(all) let description : String 

    init(_ v : {FindVerifier.Verifier}, input: {String : AnyStruct}) {
        self.result=v.verify(input)
        self.description=v.description
    }
}