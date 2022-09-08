// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts@4.7.3/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts@4.7.3/access/Ownable.sol";

contract ContentContributorPass is ERC1155, Ownable{
    event Airdropped(address account, uint256 tokenId);
    event Claimed(address account, uint256 tokenId);
    event RemovedFromAllowlist(address account);
    event AddedToAllowlist(address account);

    uint256 immutable MAX_SUPPLY;
    uint256 minted = 0;
 
    mapping(address => bool) public claimed;
    mapping(address => bool) public allowlist;
    mapping(address => bool) public airdropped;

    constructor(uint256 maxSupply, address[] memory _whitelist) ERC1155("MemberPass") {
        require(_whitelist.length > 0, "Empty allowlist provided");
        MAX_SUPPLY = maxSupply;

        for(uint i=0; i< _whitelist.length; i++){
            allowlist[_whitelist[i]] = true;
        }
    }

    //sets the base URI
    function setURI(string memory newuri) public onlyOwner {
        _setURI(newuri);
    }

    //mints the nft to the account
    function mint(address account, uint256 id)
        internal
    {   
        //This contract represents only 1 single NFT hence only tokenId 1 is possible
        require(id==1, "Token doesn't exists");

        //check if number of minted nft exceeds Maximum Supply
        require(minted+1 <= MAX_SUPPLY, "Not enough supply");

        _mint(account, id, 1, "");
        minted += 1;
    }

    //airdrops nfts to all the accounts passed as paramater to the function
    function airdrop(uint256 tokenId, address[] memory accounts) 
        external
        onlyOwner 
    {
        require(tokenId == 1, "TokenId doesn't exists!");

        for(uint i = 0; i < accounts.length; i++) {
        
            //Skip the address if it's not present in the allowlist or if it has been airdropped nft already
            if(allowlist[accounts[i]] == false || airdropped[accounts[i]] == true ){
                continue;
            }
            airdropped[accounts[i]] = true;
            emit Airdropped(accounts[i], tokenId);
        }
    }

    //adds the list of addresses to the Allowlist
    function addToAllowlist(address[] memory _recipients) 
        external
        onlyOwner 
    {
        for(uint i = 0; i < _recipients.length; i++) {
            allowlist[_recipients[i]] = true;
            emit AddedToAllowlist(_recipients[i]);
        }
    }

    //removes the list of addresses from the allowlist
    function removeFromAllowlist(address[] memory _recipients) 
        external 
        onlyOwner
    {
        for(uint i = 0; i < _recipients.length; i++) {
            allowlist[_recipients[i]] = false;
            emit RemovedFromAllowlist(_recipients[i]);
        }
    }

    //mints the nft to the address(msg.sender) who was aidropped the nft 
    function claim() external {
        require(allowlist[msg.sender] == true, "Address not present in the allowlist!");
        require(airdropped[msg.sender] == true, "You don't have any NFT!");
        require(claimed[msg.sender] == false, "NFT Already Claimed!");

        claimed[msg.sender] = true;

        mint(msg.sender, 1);
        
        emit Claimed(msg.sender, 1);
    }

}
