// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts@4.7.3/access/Ownable.sol";
import "@openzeppelin/contracts@4.7.3/token/ERC1155/extensions/ERC1155URIStorage.sol";

contract NFTDetail is Ownable, ERC1155URIStorage{
    event RemovedFromAllowlist(address account, uint256 tokenId);
    
    event AddedToAllowlist(address account, uint256 tokenId);
    
    struct nft{
        string name;
        uint256 tokenId;
        uint256 price;
        address creator;
        uint256 maxCopies;
        uint256 minted;
        uint256 airdropped;
        uint256 creationTime;
        uint256 burnTime;
        bool isTransferrable;
        uint256[] rewardNFT;
        string uri;
        bool isSet;
    }

    struct NFTAirdrop{
        address receiver;
        uint256 amount;
    }
    
    mapping(uint256 => bool) public voucherUsed;
    mapping(uint256 => mapping(address => bool)) public allowlist;
    mapping(uint256 => mapping(address => uint256)) public airdropped;
    mapping(uint256 => mapping(address => uint256)) public claimed;
    //mapping(uint256 => string) public _uris;

    mapping(uint256 => nft) public nfts;

    address contractAddr;

    modifier isValidId(uint256 tokenId){
        require(nfts[tokenId].isSet);
        _;
    }

    modifier onlyContractAddreess(address _contractAddr){
        require(contractAddr == _contractAddr,"Caller is not Authrorised Contract Address");
        _;
    }

    constructor() ERC1155("ipfs://bafybeidcf6zgua6jmzxpmhq6uey3izacstycsneeleyvhjnozmm5djyxcq/{id}.json"){}

    function setNFTDetails(
        string memory _name, 
        uint256 _tokenId, 
        uint256 _price, 
        address _creator, 
        uint256 _maxCopies, 
        bool _isTransferrable,
        uint256[] memory _rewardNFT,
        string memory _uri
    ) public onlyOwner {
        nft storage nftpass = nfts[_tokenId];
        require(!nftpass.isSet, "NFT cannot be set twice");
        nftpass.name = _name;
        nftpass.tokenId = _tokenId;
        nftpass.price = _price;
        nftpass.creator =  _creator;
        nftpass.maxCopies  = _maxCopies;
        nftpass.minted = 0;
        nftpass.airdropped = 0;
        nftpass.creationTime = block.timestamp;
        nftpass.burnTime = block.timestamp + 31536000;
        nftpass.isTransferrable = _isTransferrable;
        nftpass.rewardNFT = _rewardNFT;
        nftpass.uri = _uri;
        nftpass.isSet = true;

        _setURI(_tokenId, _uri);
    }

    function getNFTDetails(uint256 tokenId) public view returns(nft memory){
        return nfts[tokenId];
    }

    function getAllowlisted(uint256 tokenId, address user) public view returns(bool){
        return allowlist[tokenId][user];
    }

    function getAirdroppedAmount(uint256 tokenId, address user) public view returns(uint256){
        return airdropped[tokenId][user];
    }

    function setAirdroppedAmount(uint256 tokenId, address user, uint256 amount) public onlyContractAddreess(msg.sender){
        airdropped[tokenId][user] += amount;
    }

    function getClaimedAmount(uint256 tokenId, address user) public view returns(uint256){
        return claimed[tokenId][user];
    }

    function setClaimedAmount(uint256 tokenId, address user, uint256 amount) public onlyContractAddreess(msg.sender){
        claimed[tokenId][user] += amount;
    }

    function getVoucherUsed(uint256 nonce) public view returns(bool){
        return voucherUsed[nonce];
    }

    function setVoucherUsed(uint256 nonce) public onlyContractAddreess(msg.sender){
        voucherUsed[nonce] = true;
    }

    function setContactAddr(address _newAddr) public onlyOwner{
        contractAddr = _newAddr;
    }

    /*
    The function 'addToAllowlist' adds the list of addresses to the Allowlist
    The address[]-type input '_recipients' takes addresses to add to the Allowlist
    The uint256-type input 'tokenId' takes Token ID
    */
    function addToAllowlist(address[] memory _recipients, uint256 tokenId)
        external
        onlyOwner
        isValidId(tokenId)
    {   
        nft storage nftpass = nfts[tokenId];
        uint256 totalAirdrop = nftpass.airdropped + _recipients.length;
        require(totalAirdrop <= nftpass.maxCopies,"You exceeded the limit");
        //uint256 airdropId = tokenId;

        for(uint256 i = 0; i < _recipients.length; i++){
            allowlist[tokenId][_recipients[i]] = true;
            if(nftpass.price == 0){
                airdropped[tokenId][_recipients[i]]++;
            }
            emit AddedToAllowlist(_recipients[i], tokenId);
        }
    }


    /*
    The function 'removeFromAllowlist' removes the list of addresses from the Allowlist
    The address[]-type input '_recipients' takes addresses to remove from the Allowlist
    The uint256-type input 'tokenId' takes Token ID
    */
    function removeFromAllowlist(address[] memory _recipients, uint256 tokenId)
        external
        onlyOwner
        isValidId(tokenId)
    {
        for (uint256 i = 0; i < _recipients.length; i++) {
            allowlist[tokenId][_recipients[i]] = false;
            if(claimed[tokenId][_recipients[i]] != airdropped[tokenId][_recipients[i]]){
                airdropped[tokenId][_recipients[i]] = 0;
            }
            emit RemovedFromAllowlist(_recipients[i], tokenId);
        }
    }

    /*
    The function 'updateCopies' updates the number of copies
    The uint256-type input 'tokenId' takes Token ID
    The uint256-type input 'newCopies' takes new nmuber of copies
    */
    function updateCopies(uint256 tokenId, uint256 newCopies) public onlyOwner isValidId(tokenId){
        require(newCopies > 0, "Copies cannot be zero");

        nfts[tokenId].maxCopies = newCopies;
    }

    

}
