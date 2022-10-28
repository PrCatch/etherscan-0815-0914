// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "ERC721A.sol";
import "Ownable.sol";
import "MerkleProof.sol";

contract WorldDataMiners is ERC721A, Ownable {
    using Strings for uint256;

    string public baseURI;

    bool public public_mint_status = true;
    bool public wl_mint_status = true;    
    bool public paused = false;
    bool public presale_status = true;

    uint256 MAX_SUPPLY = 10000;

    string public notRevealedUri;
    
    bool public revealed = true;

    uint256 public whitelistCost = 0.039 ether;
    uint256 public publicSaleCost = 0.069 ether;
    uint256 public presale_cost = 0.039 ether;
    uint256 public max_per_wallet = 20;

    uint256 public total_PS_count;
    uint256 public total_presale_count;
    uint256 public total_wl_count;

    uint256 public total_PS_limit = 8500;
    uint256 public total_presale_limit = 1000;
    uint256 public total_wl_limit = 500;

    bytes32 public whitelistSigner;

    constructor(string memory _initBaseURI, string memory _initNotRevealedUri) ERC721A("WorldDataMiners", "WDM") {
    
    setBaseURI(_initBaseURI);
    setNotRevealedURI(_initNotRevealedUri);   
    mint(99); 
    }

     function mint(uint256 quantity) public payable  {
        require(totalSupply() + quantity <= MAX_SUPPLY,"No More NFTs to Mint");

        if (msg.sender != owner()) {

            require(!paused, "the contract is paused");
            require(balanceOf(msg.sender) + quantity <= max_per_wallet, "Per Wallet Limit Reached");

            if(presale_status){
                
                require(total_presale_count + quantity <= total_presale_limit, "Presale Limit Reached");
                require(msg.value >= (presale_cost * quantity), "Not Enough ETH Sent"); 
                total_presale_count = total_presale_count + quantity; 

            } else if(public_mint_status){

                require(total_PS_count + quantity <= total_PS_limit, "Public Sale Limit Reached");  
                require(msg.value >= (publicSaleCost * quantity), "Not Enough ETH Sent");  
                total_PS_count = total_PS_count + quantity;

            }                           
           
        }

        _safeMint(msg.sender, quantity);
        
        }
   
    // whitelist minting 

   function whitelistMint(bytes32[] calldata  _proof, uint256 quantity) payable public{

   require(totalSupply() + quantity <= MAX_SUPPLY, "Not enough tokens left");
   require(wl_mint_status, "whitelist mint is off");
   require(balanceOf(msg.sender) + quantity <= max_per_wallet,"Per wallet limit reached");
   require(total_wl_count + quantity <= total_wl_limit, "Whitelist Limit Reached");

   require(msg.value >= whitelistCost * quantity, "insufficient funds");

   bytes32 leaf = keccak256(abi.encodePacked(msg.sender));
   require(MerkleProof.verify(_proof,leaf,whitelistSigner),"Invalid Proof");
   total_wl_count = total_wl_count + quantity; 
   _safeMint(msg.sender, quantity);
  
  }


    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        if (!_exists(tokenId)) revert URIQueryForNonexistentToken();

        if(revealed == false) {
        return notRevealedUri;
        }
      
        return bytes(baseURI).length != 0 ? string(abi.encodePacked(baseURI, tokenId.toString(),".json")) : '';
    }



    function _baseURI() internal view override returns (string memory) {
        return baseURI;
    }


    //only owner      
    
    function toggleReveal() public onlyOwner {
        
        if(revealed==false){
            revealed = true;
        }else{
            revealed = false;
        }
    }   

    function toggle_paused() public onlyOwner {
        
        if(paused==false){
            paused = true;
        }else{
            paused = false;
        }
    } 
        
    function toggle_public_mint_status() public onlyOwner {
        
        if(public_mint_status==false){
            public_mint_status = true;
        }else{
            public_mint_status = false;
        }
    }  

    function toggle_wl_mint_status() public onlyOwner {
        
        if(wl_mint_status==false){
            wl_mint_status = true;
        }else{
            wl_mint_status = false;
        }
    } 

    function setStatus_presale() public onlyOwner{

        if(presale_status == true){

        presale_status = false;

        } else {

        presale_status = true;        

        }

    }

    function setNotRevealedURI(string memory _notRevealedURI) public onlyOwner {
        notRevealedUri = _notRevealedURI;
    }
  
    function setWhitelistSigner(bytes32 newWhitelistSigner) external onlyOwner {
        whitelistSigner = newWhitelistSigner;
    }
   
    function withdraw() public payable onlyOwner {
  
    (bool main, ) = payable(owner()).call{value: address(this).balance}("");
    require(main);
    }

    function setWhitelistCost(uint256 _whitelistCost) public onlyOwner {
        whitelistCost = _whitelistCost;
    }
    
    function setPublicSaleCost(uint256 _publicSaleCost) public onlyOwner {
        publicSaleCost = _publicSaleCost;
    }

    function set_presale_cost(uint256 _presale_cost) public onlyOwner {
        presale_cost = _presale_cost;
    }

    function set_total_PS_limit(uint256 _total_PS_limit) public onlyOwner {
        total_PS_limit = _total_PS_limit;
    }

    function set_total_presale_limit(uint256 _total_presale_limit) public onlyOwner {
        total_presale_limit = _total_presale_limit;
   }

   function set_total_wl_limit(uint256 _total_wl_limit) public onlyOwner {
        total_wl_limit = _total_wl_limit;
   }

    function setMax_per_wallet(uint256 _max_per_wallet) public onlyOwner {
        max_per_wallet = _max_per_wallet;
    }

    function setMAX_SUPPLY(uint256 _MAX_SUPPLY) public onlyOwner {
        MAX_SUPPLY = _MAX_SUPPLY;
    }

    function setBaseURI(string memory _newBaseURI) public onlyOwner {
        baseURI = _newBaseURI;
   }
       
}