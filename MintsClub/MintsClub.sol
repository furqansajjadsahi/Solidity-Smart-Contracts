// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Burnable.sol";
import "@openzeppelin/contracts@4.4.2/utils/Counters.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract MintsClub is ERC1155, Ownable,ERC1155Burnable , ReentrancyGuard{
    
    using Counters for Counters.Counter;
    using SafeMath for uint;
    
    Counters.Counter private _tokenIdCounter;
    
    uint256 public amountfee ;
    uint256 public royaltyfee;
    address payable public nftownerAddress;
    address  public seller;
    address  public productowner = 0x78731D3Ca6b7E34aC0F824c42a7cC18A495cabaB;
    uint256 public default_Fee = 20;
    mapping(uint256 => address) public _owners;
    address payable public beneficiary;
    address public nftminter;
    // uint   public auctionEndTime;
    // uint   public auctionStartTime;
    bool ended =false;
    address public highestBidder;
    uint    public highestBid;
    struct FixedPrice{
            uint256 fixedid;
                uint256 price ;
                address owner;
                uint256 paid;
                address newowner;
                bool forsale;
                uint256 totalcopies;
                uint256 tokenid;
                 bool isSold;
            }
        FixedPrice[] public Fixedprices;

   struct Auction {
    
       uint256 auctionid;
       address payable beneficiary;
        uint256 tokenId;
        bool OpenForBidding;
        uint256 currentBidAmount;
        address  currentBidOwner;
        uint numberofcopies;
        uint256    auctionStartTime;
          uint256    auctionEndTime;
        
        // bool amountStatus;
        // uint256 timestamp;
        bool isSold;
    }    

        Auction[] public auctions;


    // mapping(uint256 => FixedPrice) public Fixedprices; // tokenId => tokenId fixed Price
    // event AuctionSet(address _auction_owner ,uint256 _auctionid);
    event HighestBidIcrease(address bidder, uint amount);
    event OfferSale(uint256 _fixeditemid);
    event AuctionStart(uint256 _auctionid);
   
    event AuctionEnded(address winner, uint amount);
    // mapping (uint256 => Auction) public auctions;
    mapping(address => uint) public pendingResturns;
    string public name;
    mapping(uint256 => string) private _tokenURIs;
    string private _baseURI = "";
    constructor(string memory _name) ERC1155(_name) {
        setName(_name);
    }
  
    function uri(uint256 tokenId) public view virtual override returns (string memory) {
        string memory tokenURI = _tokenURIs[tokenId];
        return bytes(tokenURI).length > 0 ? string(abi.encodePacked(_baseURI, tokenURI)) : super.uri(tokenId);
    }
   
    function _setURI(uint256 tokenId, string memory tokenURI) internal virtual {
        _tokenURIs[tokenId] = tokenURI;
        emit URI(uri(tokenId), tokenId);
    }
    function _setBaseURI(string memory baseURI) internal virtual {
        _baseURI = baseURI;
    }
    function setName(string memory _name) public  {
        name = _name;
    }
    modifier onlyTokenHolders(uint256 tokenid){
        require(balanceOf(msg.sender,tokenid) > 0 , "Only owners of this token can access this");
         _;
    }

    
      modifier ItemExists(uint256 id){
        require(id < Fixedprices.length && Fixedprices[id].fixedid == id, "Could not find Item");
        _;
    }

      modifier IsForSale(uint256 id){
        require(Fixedprices[id].isSold == false, "Item is already sold");
        _;
    }
 
    function mint(address account, uint256 amount, string memory tokenuri)  public nonReentrant{
          uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        _mint(account, tokenId, amount, '0x00');
      _setURI(tokenId,tokenuri);
          _owners[tokenId] = account;
          nftminter = account;  
    }
    
    
    function putonsale(uint256 _tokenId,uint256 amount,uint256 _price) public nonReentrant onlyTokenHolders(_tokenId) returns(uint256){
            uint256 newItemId = Fixedprices.length;
            Fixedprices.push(FixedPrice(newItemId,_price,msg.sender,0,address(0),true,amount,_tokenId,false));
            emit OfferSale(newItemId);
            return newItemId;
    }

    

    function BuyFixedPriceNFT(uint256 Id)payable public nonReentrant ItemExists(Id) IsForSale(Id) returns (bool){
        require(msg.value >=  Fixedprices[Id].price,"send wrong amount in fixed price");
        require(Fixedprices[Id].forsale,"This NFT is not for sale");
        Fixedprices[Id].paid = msg.value; 
        Fixedprices[Id].newowner = msg.sender;
        _safeTransferFrom(Fixedprices[Id].owner,Fixedprices[Id].newowner,Fixedprices[Id].tokenid,Fixedprices[Id].totalcopies,'');
        uint256 onePercentofTokens = Fixedprices[Id].paid.mul(100).div(100 * 10 ** uint256(2));
        uint256 twoPercentOfTokens = onePercentofTokens.mul(2);
        uint256 halfPercentOfTokens = onePercentofTokens.div(2);
        amountfee = twoPercentOfTokens + halfPercentOfTokens;
        royaltyfee = twoPercentOfTokens + halfPercentOfTokens;
        payable(Fixedprices[Id].owner).transfer(Fixedprices[Id].paid.sub(amountfee+royaltyfee));
        payable(nftminter).transfer(royaltyfee);
        payable(productowner).transfer(amountfee);
        Fixedprices[Id].isSold = true;
        return true;
    }
   
     function startAuction(uint _biddingStartTime,uint _biddingendtime , address payable _beneficiary , uint256 tokenId, uint256 _numberofcopies) public nonReentrant
      onlyTokenHolders(tokenId) returns(uint256){
             uint256 newauctionid = auctions.length;

        auctions.push(Auction(newauctionid,_beneficiary,tokenId,true,0,address(0),_numberofcopies,_biddingStartTime,_biddingendtime,false));
        emit AuctionStart(newauctionid);

        return newauctionid;
       
    }

    function bid( uint256 Id) payable public nonReentrant {
        require(auctions[Id].OpenForBidding,"Bidding is not open yet");
        address  currentBidOwner = auctions[Id].currentBidOwner;
        uint256  currentBidAmount = auctions[Id].currentBidAmount;
        if(msg.value <=  currentBidAmount) {
            revert("There is already higer or equal bid exist");
        }
        if( currentBidAmount !=0) {
            pendingResturns[currentBidOwner] += currentBidAmount;
        }
        if(msg.value > currentBidAmount ) {
            payable(currentBidOwner).transfer(currentBidAmount);
        }
        auctions[Id].currentBidOwner = msg.sender;
        auctions[Id].currentBidAmount = msg.value; 
        highestBidder =  auctions[Id].currentBidOwner;
        highestBid =  auctions[Id].currentBidAmount;
        emit HighestBidIcrease(msg.sender , msg.value);
    }
    

     function auctionEnd(uint256 Id) public nonReentrant{
        if(!auctions[Id].OpenForBidding){
            revert("The function auctionEnded is already called");
        }
        if(auctions[Id].currentBidOwner != address(0)){
        emit   AuctionEnded(highestBidder , highestBid);
        uint256 onePercentofTokens = highestBid.mul(100).div(100 * 10 ** uint256(2));
        uint256 twoPercentOfTokens = onePercentofTokens.mul(2);
        uint256 halfPercentOfTokens = onePercentofTokens.div(2);
        amountfee = twoPercentOfTokens + halfPercentOfTokens;
        royaltyfee = twoPercentOfTokens + halfPercentOfTokens;
        auctions[Id].beneficiary.transfer(highestBid.sub(amountfee+royaltyfee));
        payable(nftminter).transfer(royaltyfee);
        payable(productowner).transfer(amountfee);
        safeTransferFrom(auctions[Id].beneficiary,highestBidder,auctions[Id].tokenId,auctions[Id].numberofcopies,'');
         auctions[Id].isSold = true;
        }
        //  delete auctions[Id];
        }

        function claimNft(uint256 Id) public nonReentrant returns(bool) {

             if(!auctions[Id].OpenForBidding){
            revert("You already have claimed for your NFT");
        }
        emit   AuctionEnded(highestBidder , highestBid);
        uint256 onePercentofTokens = highestBid.mul(100).div(100 * 10 ** uint256(2));
        uint256 twoPercentOfTokens = onePercentofTokens.mul(2);
        uint256 halfPercentOfTokens = onePercentofTokens.div(2);
        amountfee = twoPercentOfTokens + halfPercentOfTokens;
        royaltyfee = twoPercentOfTokens + halfPercentOfTokens;
         auctions[Id].beneficiary.transfer(highestBid.sub(amountfee+royaltyfee));
        payable(nftminter).transfer(royaltyfee);
        payable(productowner).transfer(amountfee);
        _safeTransferFrom(auctions[Id].beneficiary,msg.sender,auctions[Id].tokenId,auctions[Id].numberofcopies,'');
        auctions[Id].isSold = true;
        //  delete auctions[Id];
        return true;
        }
   
}
