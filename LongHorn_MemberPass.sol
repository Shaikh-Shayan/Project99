// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts@4.7.3/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts@4.7.3/access/Ownable.sol";
import "@openzeppelin/contracts@4.7.3/token/ERC1155/extensions/ERC1155Burnable.sol";
import "@openzeppelin/contracts@4.7.3/utils/cryptography/draft-EIP712.sol";
import "@openzeppelin/contracts@4.7.3/utils/cryptography/ECDSA.sol";

//["0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2","0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db","0x78731D3Ca6b7E34aC0F824c42a7cC18A495cabaB","0x23079599b4950D89429F1C08B2ed2DC820955Fd5"]
contract NFT is ERC1155, ERC1155Burnable, EIP712, Ownable{

    /*
    @dev The event 'NFTPurchased' must be emitted when an account purchases the NFT
    The uint256-type member 'tokenId' takes Token ID
    The uint256-type member 'nonce' takes nonce
    The uint256-type member 'copies' takes copies
    The address-type member 'account' takes buyer's address
    The uint256-type member 'amount' takes token amount
    */
    event NFTPurchased(uint256 tokenId, uint256 nonce, uint256 copies, address buyer, uint256 amount);
    /*
    @dev The event 'Airdropped' must be emitted when an account is airdropped tokens
    The address-type member 'account' takes receiver's address
    The uint256-type member 'tokenId' takes Token ID
    */
    event Airdropped(address account, uint256 tokenId);
    /*
    @dev The event 'MemberPassClaimed' must be emitted when a pass is claimed
    The address-type member 'account' takes receiver's address
    The uint256-type member 'tokenId' takes Token ID
    */
    event MemberPassClaimed(address account, uint256 tokenId);
    /*
    @dev The event 'NFTBurned' must be emitted when an NFT is burned from an address
    The address-type member 'account' takes receiver's address
    The uint256-type member 'tokenId' takes Token ID
    */
    event NFTBurned(address account, uint256 tokenId);

    string private constant SIGNING_DOMAIN = "Voucher-Domain";
    string private constant SIGNING_VERSION = "1";
    /*
    The mapping 'MAX_COPIES' stores maximum number of copies
    The mapping 'minted' stores minted number of copies
    */
    mapping(uint256 => uint256) MAX_COPIES;
    mapping(uint256 => uint256) minted;
    uint256 creationTime;
    uint256 burnTime;

    /*
    The struct 'NFTVoucher' is a struct for vouchers with all the info
    The uint256-type member 'tokenId' stores Token ID
    The uint256-type member 'minPrice' stores minimum price
    The uint256-type member 'copies' stores copies
    The address-type member 'artist' stores artist's address
    The bytes-type member 'signature' stores signature
    */
    struct NFTVoucher {
        uint256 tokenId;
        uint256 minPrice;
        uint256 copies;
        address artist;
        /*The signature proves that the NFT creator authorized the creation 
        of the specific NFT described in the voucher.
        */
        bytes signature;
        
    }

    /*
    The mapping 'voucherUsed'  is Signature Tracker
    The mapping 'claimed'  keeps track of claimed and unclaimed airdrops
    The mapping 'airdropped'  keeps track of airdropped number of tokens
    */
    mapping(uint256 => bool) public voucherUsed;
    mapping(address => bool) public claimed;
    mapping(address => uint256) public airdropped;

    /*
    The contract constructor takes 4 arguments while deploying
    The uint256-type input 'longhorn_copies' takes number of copies for Longhorn
    The uint256-type input 'memberpass_copies' takes number of copies for Member Pass
    */
    constructor(uint256 longhorn_copies, uint256 memberpass_copies) ERC1155("LongHorn_MemberPass") EIP712(SIGNING_DOMAIN, SIGNING_VERSION) {
        creationTime = block.timestamp;
        //365(days)*24(hours)*60(minutes)*60(seconds) = 31536000 seconds
        burnTime = creationTime + 31536000;
        MAX_COPIES[1] = longhorn_copies;
        MAX_COPIES[2] = memberpass_copies;
    }

    /*
    The function 'setURI' sets the base URI
    The string-type input 'newuri' takes the URI
    */
    function setURI(string memory newuri) public onlyOwner{
        _setURI(newuri);
    }

    /*
    function 'redeem' takes a voucher as an argument and lets the user redeem the signed voucher
    The NFTVoucher-type member 'voucher' takes voucher
    The address-type member 'account' takes buyer's address
    The uint256-type member 'nonce' takes nonce
    */
    function redeem(NFTVoucher calldata voucher, address buyer, uint256 nonce)
        public
        payable
    {   
        
        /*
        Check if the signature is valid and belongs to the account that's authorized to mint NFTs
        */
        address signer = _verify(voucher);
        require(signer == voucher.artist, "Invalid signer");

        /*
        Check to see if user has already used the signature
        */
        require(!voucherUsed[nonce], "This voucher has already been used.");

        require(voucher.tokenId == 1 || voucher.tokenId == 2, "Token doesn't exist");
        require(minted[voucher.tokenId] + voucher.copies <= MAX_COPIES[voucher.tokenId], "Not enough supply");
        require(msg.value >= voucher.minPrice * voucher.copies * 1 wei, "Not enough ethers sent");

        /*
        transferring the funds to the owner
        */
        payable(owner()).transfer(msg.value);

        /*
        minting NFT
        */
        _mint(buyer, voucher.tokenId, voucher.copies, "");
        minted[voucher.tokenId] += voucher.copies;
        voucherUsed[nonce] = true;

        /*
        airdropping MemberPass NFT to the long horn NFT buyers
        */
        if(voucher.tokenId == 1)
            airdrop(buyer);

        emit NFTPurchased(voucher.tokenId, nonce, voucher.copies, buyer, msg.value);
    }


    /*
    The function 'airdrop' airdrops nfts to the account passed as param to the function
    The address-type member 'account' takes receiver's address
    */
    function airdrop(address account) 
        internal
    {   
        /*
        check if number of airdropped Member Pass Nft exceeds Maximum Supply
        */
        require(minted[2]+1<= MAX_COPIES[2], "Not enough supply");

        airdropped[account]++;
        emit Airdropped(account, 1);
    }


    /*
    The function 'claim' mints the nft to the address(msg.sender) who was aidropped the nft 
    The address-type input 'account' takes receiver's address
    */
    function claim(address account) 
        external 
    {
        require(airdropped[account] > 0, "You don't have any NFT!");

        airdropped[account]--;

        _mint(account, 2, 1, "");
        
        emit MemberPassClaimed(account, 2);
    }

    /*
    The function 'burn' burns the nft only after 1 year
    The address-type input 'account' takes  address
    The uint256-type input 'id' takes Token ID
    The uint256-type input 'value' takes value
    */
    function burn(
        address account,
        uint256 id,
        uint256 value
    ) public override {
        require(
            account == _msgSender() || isApprovedForAll(account, _msgSender()),
            "ERC1155: caller is not token owner or approved"
        );
        /*
        Require statement checks that the time has exceeded burn rate, i.e., 1 year
        */
        require(block.timestamp > burnTime, "You are not allowed to burn the nft before 1 year");

        emit NFTBurned(account, id);
        super.burn(account, id, value);
    }

    /*
    The function 'updateCopies' updates the number of copies
    The uint256-type input 'tokenId' takes Token ID
    The uint256-type input 'newCopies' takes new nmuber of copies
    */
    function updateCopies(uint256 tokenId, uint256 newCopies) 
        public 
        onlyOwner
    {
        require(tokenId == 1|| tokenId == 2, "TokenId doesn't exists");
        require(newCopies>0, "Copies cannot be zero");

        MAX_COPIES[tokenId] = newCopies;
    }

    /*
    The function '_verify' verifies signature against input and recovers address, 
    or reverts transaction if signature is invalid
    The NFTVoucher-type input 'voucher' takes voucher
    */
    function _verify(NFTVoucher calldata voucher) public view returns (address) {
        bytes32 digest = _hash(voucher);
        return ECDSA.recover(digest, voucher.signature);
    }

    /*
    The function '_hash' returns the hash of the argument passed
    The NFTVoucher-type input 'voucher' takes voucher
    */
    function _hash(NFTVoucher calldata voucher) internal view returns (bytes32) {
        return _hashTypedDataV4(keccak256(abi.encode(
            keccak256("NFTVoucher(uint256 tokenId,uint256 minPrice,uint256 copies,address artist)"),
            voucher.tokenId,
            voucher.minPrice,
            voucher.copies,
            voucher.artist
        )));
    }

}
