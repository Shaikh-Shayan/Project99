// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts@4.7.3/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts@4.7.3/access/Ownable.sol";
import "@openzeppelin/contracts@4.7.3/token/ERC1155/extensions/ERC1155Burnable.sol";
import "@openzeppelin/contracts@4.7.3/utils/cryptography/draft-EIP712.sol";
import "@openzeppelin/contracts@4.7.3/utils/cryptography/ECDSA.sol";

contract NFT is ERC1155, ERC1155Burnable, EIP712, Ownable{
    event NFTPurchased(uint256 tokenId, uint256 nonce, address buyer, uint256 amount);
    event Airdropped(address account, uint256 tokenId);
    event MemberPassClaimed(address account, uint256 tokenId);
    event NotAirdropped(address account);
    event Withdrawn(uint256 amount);
    event NFTBurned(address account, uint256 tokenId);

    string private constant SIGNING_DOMAIN = "Voucher-Domain";
    string private constant SIGNING_VERSION = "1";
    mapping(uint256 => uint256) COPIES;
    mapping(uint256 => uint256) minted;
    uint256 creationTime;
    uint256 burnTime;

    address immutable MINTER_ROLE;

    //NFT Voucher contains all the information that will go in the actual NFT
    struct NFTVoucher {
        uint256 tokenId;
        uint256 nonce;
        uint256 minPrice;
        address buyer;
        //The signature proves that the NFT creator authorized the creation of the specific NFT described in the voucher.
        bytes signature;
    }

    //Signature Tracker
    mapping(uint256 => bool) public voucherUsed;
    
    mapping(address => bool) public claimed;
    mapping(address => bool) public airdropped;
    
    constructor(address signer, uint256 longhorn_copies, uint256 memberpass_copies) ERC1155("LongHorn_MemberPass") EIP712(SIGNING_DOMAIN, SIGNING_VERSION) {
        MINTER_ROLE = signer;
        creationTime = block.timestamp;
        //365(days)*24(hours)*60(minutes)*60(seconds) = 31536000 seconds
        burnTime = creationTime + 31536000;
        COPIES[1] = longhorn_copies;
        COPIES[2] = memberpass_copies;
    }

    //sets the base URI
    function setURI(string memory newuri) public onlyOwner{
        _setURI(newuri);
    }

    //takes a voucher as an argument and let's the user redeem the signed voucher
    function redeem(NFTVoucher calldata voucher)
        public
        payable
    {   
        
        //Check if the signature is valid and belongs to the account that's authorized to mint NFTs
        address signer = _verify(voucher);
        require(signer == MINTER_ROLE, "Invalid signer");

        //Check to see if user has already used the signature
        require(!voucherUsed[voucher.nonce], "This voucher has already been used.");

        require(voucher.tokenId == 1 || voucher.tokenId == 2, "Token doesn't exist");
        require(minted[voucher.tokenId]<COPIES[voucher.tokenId], "Not enough supply");
        require(msg.value >= voucher.minPrice* 1 wei, "Not enough ethers sent");

        _mint(voucher.buyer, voucher.tokenId, 1, "");
        payable(owner()).transfer(msg.value);

        minted[voucher.tokenId] += 1;
        voucherUsed[voucher.nonce] = true;

        emit NFTPurchased(voucher.tokenId, voucher.nonce, voucher.buyer, msg.value);
    }


    //airdrops nfts to all the accounts passed as paramater to the function
    function airdrop(address[] memory accounts) 
        external
        onlyOwner 
    {   
        //check if number of airdropped Member Pass Nft exceeds Maximum Supply
        require(minted[2]+accounts.length<= COPIES[2], "Not enough supply");

        for(uint i = 0; i < accounts.length; i++) {
            //Skip the address if it doesn't own any Long Horn NFT or if it has been airdropped nft already
            if(balanceOf(accounts[i], 1) < 1 || airdropped[accounts[i]] == true){
                emit NotAirdropped(accounts[i]);
                continue;
            }

            airdropped[accounts[i]] = true;
            emit Airdropped(accounts[i], 1);
        }
    }


    //mints the nft to the address(msg.sender) who was aidropped the nft 
    function claim(address account) 
        external 
    {
        require(airdropped[account] == true, "You don't have any NFT!");
        require(claimed[account] == false, "NFT Already Claimed!");

        claimed[account] = true;

        _mint(account, 2, 1, "");
        
        emit MemberPassClaimed(account, 2);
    }

    //burns the nft only after 1 year
    function burn(
        address account,
        uint256 id,
        uint256 value
    ) public override {
        require(
            account == _msgSender() || isApprovedForAll(account, _msgSender()),
            "ERC1155: caller is not token owner or approved"
        );
        //burn rate:- 1 year
        require(block.timestamp > burnTime, "You are not allowed to burn the nft before 1 year");

        emit NFTBurned(account, id);
        super.burn(account, id, value);
    }

    //updates the number of copies
    function updateCopies(uint256 tokenId, uint256 newCopies) 
        public 
        onlyOwner
    {
        require(tokenId == 1|| tokenId == 2, "TokenId doesn't exists");
        require(newCopies>0, "Copies cannot be zero");

        COPIES[tokenId] = newCopies;
    }

    //let's the owner withdraw the funds from the contract
    function withdraw() public onlyOwner{
        uint256 amount = address(this).balance;
        require(amount >0, "Balance is 0");
        
        payable(owner()).transfer(amount);

        emit Withdrawn(amount);
    }

    //verifies signature against input and recovers address, or reverts transaction if signature is invalid
    function _verify(NFTVoucher calldata voucher) public view returns (address) {
        bytes32 digest = _hash(voucher);
        return ECDSA.recover(digest, voucher.signature);
    }

    //returns the hash of the argument passed
    function _hash(NFTVoucher calldata voucher) internal view returns (bytes32) {
        return _hashTypedDataV4(keccak256(abi.encode(
            keccak256("NFTVoucher(uint256 tokenId,uint256 nonce,uint256 minPrice,address buyer)"),
            voucher.tokenId,
            voucher.nonce,
            voucher.minPrice,
            voucher.buyer
        )));
    }

}
