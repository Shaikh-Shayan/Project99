// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts@4.7.3/access/Ownable.sol";
import "@openzeppelin/contracts@4.7.3/token/ERC1155/extensions/ERC1155URIStorage.sol";

contract NFTStorage is Ownable, ERC1155URIStorage {
    event RemovedFromAllowlist(address account, uint256 tokenId);

    event AddedToAllowlist(address account, uint256 tokenId);

    //struct containing all the details regarding an NFT
    struct NFTDetails {
        string name;
        uint256 tokenId;
        uint256 price;
        address creator;
        uint256 maxCopies;
        uint256 minted;
        uint256 noOfNFTAirdropped;
        uint256 creationTime;
        uint256 burnTime;
        bool isTransferrable;
        uint256[] rewardNFTs;
        string uri;
        bool isSet;
    }

    //Tracks the voucher that have already been used
    mapping(uint256 => bool) public voucherUsed;
    //Stores the allowlist for all NFTs
    mapping(uint256 => mapping(address => bool)) public allowlist;
    //Tracks the number of NFTs airdropped to an address for each tokenId
    mapping(uint256 => mapping(address => uint256)) public airdroppedToAddress;
    //Tracks the number of NFTS claimed by an address for each tokenId
    mapping(uint256 => mapping(address => uint256)) public claimed;
    //Stores the NFTDetails for all NFTs
    mapping(uint256 => NFTDetails) public NftAtId;

    //Contract address of NFTMarketPlace
    address public NFTMarketPlaceAddress;

    //Checks whether NFT with given tokenId exists
    modifier isValidId(uint256 tokenId) {
        require(NftAtId[tokenId].isSet, "INVALID NFT TOKEN-ID");
        _;
    }

    //Checks if the address given is the Authorised contract address
    modifier onlyContractAddreess(address _NFTMarketPlaceAddress) {
        require(
            NFTMarketPlaceAddress == _NFTMarketPlaceAddress,
            "CALLER NOT AUTHORISED"
        );
        _;
    }

    constructor()
        ERC1155(
            "ipfs://bafybeidcf6zgua6jmzxpmhq6uey3izacstycsneeleyvhjnozmm5djyxcq/{id}.json"
        )
    {}

    /*
    function 'setNFTDetails' sets the details for the given NFT
    The string-type member '_name' takes the name of the NFT
    The uint256-type member '_tokenId' takes the token id of the NFT
    The uint256-type member '_price' takes the price of the NFT
    The uint256-type member '_maxCopies' takes the maximum number of Copies of the NFT that can be minted
    The bool-type member '_isTransferrable' takes true/false value indicating the NFT is transferrable or not
    The uint256[]-type member '_rewardNFTs' takes the array of tokenIds of NFTs that will be airdropped to a user as a reward
    The string-type member '_uri' takes the uri of the NFT
    */
    function setNFTDetails(
        string memory _name,
        uint256 _tokenId,
        uint256 _price,
        uint256 _maxCopies,
        bool _isTransferrable,
        uint256[] memory _rewardNFTs,
        string memory _uri
    ) public onlyOwner {
        NFTDetails storage NFT = NftAtId[_tokenId];
        require(!NFT.isSet, "NFT DETAILS CANNOT BE CHANGED");
        NFT.name = _name;
        NFT.tokenId = _tokenId;
        NFT.price = _price;
        NFT.creator = msg.sender;
        NFT.maxCopies = _maxCopies;
        NFT.minted = 0;
        NFT.noOfNFTAirdropped = 0;
        NFT.creationTime = block.timestamp;
        NFT.burnTime = block.timestamp + 31536000;
        NFT.isTransferrable = _isTransferrable;
        NFT.rewardNFTs = _rewardNFTs;
        NFT.uri = _uri;
        NFT.isSet = true;

        _setURI(_tokenId, _uri);
    }

    /*
    function 'getNFTDetails' gets the details for the given NFT
    The uint256-type member 'tokenId' takes the token id of the NFT
    Returns NFTDetails-type member which contains all the details of the NFT
    */
    function getNFTDetails(uint256 tokenId)
        public
        view
        returns (NFTDetails memory)
    {
        return NftAtId[tokenId];
    }

    /*
    function 'getAllowlisted' checks if the account is allowlisted or not
    The uint256-type member 'tokenId' takes the token id of the NFT
    The address-type member 'account' takes the address of the user
    Returns bool-type member indicating if the address is present in the allowlist for the given tokenId
    */
    function getAllowlisted(uint256 tokenId, address account)
        public
        view
        returns (bool)
    {
        return allowlist[tokenId][account];
    }

    /*
    function 'getAirdropppedAmount' returns the number of NFTs airdropped to the address
    The uint256-type member 'tokenId' takes the token id of the NFT
    The address-type member 'account' takes the address of the user
    Returns uint256-type member indicating the number of NFTs airdropped to the given address for given tokenId
    */
    function getAirdroppedAmount(uint256 tokenId, address account)
        public
        view
        returns (uint256)
    {
        return airdroppedToAddress[tokenId][account];
    }

    /*
    function 'setAirdropppedAmount' updates the number of NFTs airdropped to the address
    The uint256-type member 'tokenId' takes the token id of the NFT
    The address-type member 'account' takes the address of the user
    The uint256-type member 'amount' takes the number of NFTs airdropped
    */
    function setAirdroppedAmount(
        uint256 tokenId,
        address account,
        uint256 amount
    ) public onlyContractAddreess(msg.sender) {
        airdroppedToAddress[tokenId][account] += amount;
    }

    /*
    function 'getClaimedAmount' returns the number of NFTs claimed by the address
    The uint256-type member 'tokenId' takes the token id of the NFT
    The address-type member 'account' takes the address of the user
    Returns uint256-type member indicating the number of NFTs claimed by the given address for given tokenId
    */
    function getClaimedAmount(uint256 tokenId, address account)
        public
        view
        returns (uint256)
    {
        return claimed[tokenId][account];
    }

    /*
    function 'setClaimedAmount' updates the number of NFTs claimed by the address
    The uint256-type member 'tokenId' takes the token id of the NFT
    The address-type member 'account' takes the address of the user
    The uint256-type member 'amount' takes the number of NFTs claimed
    */
    function setClaimedAmount(
        uint256 tokenId,
        address account,
        uint256 amount
    ) public onlyContractAddreess(msg.sender) {
        claimed[tokenId][account] += amount;
    }

    /*
    function 'getVoucherUsed' checks if the nonce has been used or not
    The uint256-type member 'nonce' takes the nonce
    Returns bool-type member true/false indicating if the nonce has already been used or not
    */
    function getVoucherUsed(uint256 nonce) public view returns (bool) {
        return voucherUsed[nonce];
    }

    /*
    function 'setVoucherUsed' sets the voucherUsed to true for the givne nonce
    The uint256-type member 'nonce' takes the nonce
    */
    function setVoucherUsed(uint256 nonce)
        public
        onlyContractAddreess(msg.sender)
    {
        voucherUsed[nonce] = true;
    }

    /*
    function 'setNFTMarketPlaceAddress' sets the NFTMarketPlace contract address
    The address-type member '_newAddr' takes the address of the contract
    */
    function setNFTMarketPlaceAddress(address _newAddr) public onlyOwner {
        NFTMarketPlaceAddress = _newAddr;
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
        NFTDetails storage NFT = NftAtId[tokenId];
        uint256 totalAirdrop = NFT.noOfNFTAirdropped + _recipients.length;
        require(totalAirdrop <= NFT.maxCopies, "NOT ENOUGH NFT SUPPLY");
        //uint256 airdropId = tokenId;

        for (uint256 i = 0; i < _recipients.length; i++) {
            allowlist[tokenId][_recipients[i]] = true;
            if (NFT.price == 0) {
                airdroppedToAddress[tokenId][_recipients[i]]++;
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
            if (
                claimed[tokenId][_recipients[i]] !=
                airdroppedToAddress[tokenId][_recipients[i]]
            ) {
                airdroppedToAddress[tokenId][_recipients[i]] = 0;
            }
            emit RemovedFromAllowlist(_recipients[i], tokenId);
        }
    }

    /*
    The function 'updateCopies' updates the number of copies
    The uint256-type input 'tokenId' takes Token ID
    The uint256-type input 'newCopies' takes new nmuber of copies
    */
    function updateCopies(uint256 tokenId, uint256 newCopies)
        public
        onlyOwner
        isValidId(tokenId)
    {
        require(newCopies > 0, "COPIES CANNOT BE ZERO");

        NftAtId[tokenId].maxCopies = newCopies;
    }
}
