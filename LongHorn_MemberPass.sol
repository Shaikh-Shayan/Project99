// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts@4.7.3/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts@4.7.3/access/Ownable.sol";
import "@openzeppelin/contracts@4.7.3/token/ERC1155/extensions/ERC1155Burnable.sol";
import "@openzeppelin/contracts@4.7.3/utils/cryptography/draft-EIP712.sol";
import "@openzeppelin/contracts@4.7.3/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts@4.7.3/security/ReentrancyGuard.sol";

contract NFT is ERC1155, ERC1155Burnable, EIP712, Ownable, ReentrancyGuard {
    /*
    @dev The event 'NFTPurchased' must be emitted when an account purchases the NFT
    The uint256-type member 'tokenId' takes Token ID
    The uint256-type member 'nonce' takes nonce
    The uint256-type member 'copies' takes copies
    The address-type member 'account' takes buyer's address
    The uint256-type member 'amount' takes token amount
    */
    event NFTPurchased(
        uint256 tokenId,
        uint256 nonce,
        uint256 copies,
        address buyer,
        uint256 amount
    );
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
    The uint256-type member 'amount' takes token amount
    */
    event MemberPassClaimed(address account, uint256 tokenId, uint256 amount);
    /*
    @dev The event 'NFTBurned' must be emitted when an NFT is burned from an address
    The address-type member 'account' takes receiver's address
    The uint256-type member 'tokenId' takes Token ID
    */
    event NFTBurned(address account, uint256 tokenId);
    /*
    @dev The event 'RemovedFromAllowlist' must be emitted when an address is removed from allowlist
    The address-type member 'account' takes receiver's address
    The uint256-type member 'tokenId' takes Token ID
    */
    event RemovedFromAllowlist(address account, uint256 tokenId);
    /*
    @dev The event 'AddedToAllowlist' must be emitted when an address is added to allowlist
    The address-type member 'account' takes receiver's address
    The uint256-type member 'tokenId' takes Token ID
    */
    event AddedToAllowlist(address account, uint256 tokenId);

    string private constant SIGNING_DOMAIN = "Voucher-Domain";
    string private constant SIGNING_VERSION = "1";
    /*
    The mapping 'MAX_COPIES' stores maximum number of copies
    The mapping 'minted' stores minted number of copies
    */
    mapping(uint256 => uint256) MAX_COPIES;
    mapping(uint256 => uint256) public minted;
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
    TThe mapping 'allowlist' stores allowlist/whitelist addresses for NFTs
    The mapping 'airdropped'  keeps track of number of MemberPass NFTs airdropped to an account
    The mapping 'claimed' keeps track of number of MemberPass NFTs claimed by an account
    The mapping '_uris' stores the uri of all the NFTs
    */
    mapping(uint256 => bool) public voucherUsed;
    mapping(uint256 => mapping(address => bool)) public allowlist;
    mapping(address => uint256) public airdropped;
    mapping(address => uint256) public claimed;
    mapping(uint256 => string) private _uris;

    /*
    The contract constructor takes 4 arguments while deploying
    The uint256-type input 'longhorn_copies' takes number of copies for Longhorn
    The uint256-type input 'memberpass_copies' takes number of copies for Member Pass
    */
    constructor(uint256 longhorn_copies, uint256 memberpass_copies)
        ERC1155(
            "ipfs://bafybeidcf6zgua6jmzxpmhq6uey3izacstycsneeleyvhjnozmm5djyxcq/{id}.json"
        )
        EIP712(SIGNING_DOMAIN, SIGNING_VERSION)
    {
        creationTime = block.timestamp;
        //365(days)*24(hours)*60(minutes)*60(seconds) = 31536000 seconds
        burnTime = creationTime + 31536000;
        MAX_COPIES[1] = longhorn_copies;
        MAX_COPIES[2] = memberpass_copies;

        //set the token uri for LongHorn and MemberPass
        setTokenURI(
            1,
            "ipfs://bafybeidcf6zgua6jmzxpmhq6uey3izacstycsneeleyvhjnozmm5djyxcq/1.json"
        );
        setTokenURI(
            2,
            "ipfs://bafybeidcf6zgua6jmzxpmhq6uey3izacstycsneeleyvhjnozmm5djyxcq/2.json"
        );
    }

    /*
    function 'uri' returns the uri linked with a tokenId.
    The uint256-type member 'tokenId' takes token Id
    Returns string-type member which is the uri string associated with the tokenId
    */
    function uri(uint256 tokenId)
        public
        view
        virtual
        override
        returns (string memory)
    {
        return _uris[tokenId];
    }

    /*
    function 'setTokenURI' links the uri with a tokenId.
    The uint256-type member 'tokenId' takes token Id
    The string-type member '_uri' takes string uri
    */

    function setTokenURI(uint256 tokenId, string memory _uri) public onlyOwner {
        require(bytes(_uris[tokenId]).length == 0, "Cannot set uri twice");
        _uris[tokenId] = _uri;
    }

    /*
    function 'redeem' takes a voucher as an argument and lets the user redeem the signed voucher
    The NFTVoucher-type member 'voucher' takes voucher
    The address-type member 'account' takes buyer's address
    The uint256-type member 'nonce' takes nonce
    */
    function redeem(
        NFTVoucher calldata voucher,
        address buyer,
        uint256 nonce,
        uint256 copies
    ) public payable nonReentrant {
        /*
        Check wether address is present in the allowlist
        */
        require(
            allowlist[voucher.tokenId][buyer],
            "Address not present in the allowlist"
        );
        /*
        Check if the signature is valid and belongs to the account that's authorized to mint NFTs
        */
        address signer = _verify(voucher);
        require(signer == voucher.artist, "Invalid signer");

        /*
        Check to see if user has already used the signature
        */
        require(!voucherUsed[nonce], "This voucher has already been used.");

        require(
            voucher.tokenId == 1 || voucher.tokenId == 2,
            "Token doesn't exist"
        );
        require(
            minted[voucher.tokenId] + copies <= MAX_COPIES[voucher.tokenId],
            "Not enough supply"
        );
        require(
            msg.value >= voucher.minPrice * copies * 1 wei,
            "Not enough ethers sent"
        );

        /*
        transferring the funds to the owner
        */
        payable(owner()).transfer(msg.value);

        /*
        minting NFT
        */
        _mint(buyer, voucher.tokenId, copies, "");
        minted[voucher.tokenId] += copies;
        voucherUsed[nonce] = true;

        /*
        airdropping MemberPass NFT to the long horn NFT buyers
        */
        if (voucher.tokenId == 1) airdrop(buyer);

        emit NFTPurchased(voucher.tokenId, nonce, copies, buyer, msg.value);
    }

    /*
    The function 'airdrop' airdrops nfts to the account passed as param to the function
    The address-type member 'account' takes receiver's address
    */
    function airdrop(address account) internal {
        /*
        check if number of airdropped Member Pass Nft exceeds Maximum Supply
        */
        require(minted[2] + 1 <= MAX_COPIES[2], "Not enough supply");

        airdropped[account]++;
        emit Airdropped(account, 1);
    }

    /*
    The function 'noOfAirdroppedNFT' returns the number of Member Pass NFTs airdropped to an account
    The address-type member 'account' takes user's address
    Returns uint256-type value which is the number of Member Pass NFTs possessed by the specified account
    Returns uint256-type value which is the number of NFTs of given tokenId claimed by the specified account
    */

    function noOfAirdroppedNFT(address account)
        public
        view
        returns (uint256, uint256)
    {
        return (airdropped[account], claimed[account]);
    }

    /*
    The function 'addToAllowlist' adds the list of addresses to the Allowlist
    The address[]-type input '_recipients' takes addresses to add to the Allowlist
    The uint256-type input 'tokenId' takes Token ID
    */
    function addToAllowlist(address[] memory _recipients, uint256 tokenId)
        external
        onlyOwner
    {
        require(tokenId == 1 || tokenId == 2, "TokenId doesn't exists!");
        for (uint256 i = 0; i < _recipients.length; i++) {
            allowlist[tokenId][_recipients[i]] = true;
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
    {
        for (uint256 i = 0; i < _recipients.length; i++) {
            allowlist[tokenId][_recipients[i]] = false;
            emit RemovedFromAllowlist(_recipients[i], tokenId);
        }
    }

    /*
    The function 'claim' mints the nft to the address(msg.sender) who was aidropped the nft 
    The address-type input 'account' takes receiver's address
    */
    function claim(address account) external nonReentrant {
        uint256 amount = airdropped[account] - claimed[account];
        require(amount > 0, "You don't have any NFT!");

        claimed[account] += amount;

        _mint(account, 2, amount, "");

        emit MemberPassClaimed(account, 2, amount);
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
        require(
            block.timestamp > burnTime,
            "You are not allowed to burn the nft before 1 year"
        );

        emit NFTBurned(account, id);
        super.burn(account, id, value);
    }

    /*
    The function 'updateCopies' updates the number of copies
    The uint256-type input 'tokenId' takes Token ID
    The uint256-type input 'newCopies' takes new nmuber of copies
    */
    function updateCopies(uint256 tokenId, uint256 newCopies) public onlyOwner {
        require(tokenId == 1 || tokenId == 2, "TokenId doesn't exists");
        require(newCopies > 0, "Copies cannot be zero");

        MAX_COPIES[tokenId] = newCopies;
    }

    /*
    The function '_verify' verifies signature against input and recovers address, 
    or reverts transaction if signature is invalid
    The NFTVoucher-type input 'voucher' takes voucher
    */
    function _verify(NFTVoucher calldata voucher)
        public
        view
        returns (address)
    {
        bytes32 digest = _hash(voucher);
        return ECDSA.recover(digest, voucher.signature);
    }

    /*
    The function '_hash' returns the hash of the argument passed
    The NFTVoucher-type input 'voucher' takes voucher
    */
    function _hash(NFTVoucher calldata voucher)
        internal
        view
        returns (bytes32)
    {
        return
            _hashTypedDataV4(
                keccak256(
                    abi.encode(
                        keccak256(
                            "NFTVoucher(uint256 tokenId,uint256 minPrice,uint256 copies,address artist)"
                        ),
                        voucher.tokenId,
                        voucher.minPrice,
                        voucher.copies,
                        voucher.artist
                    )
                )
            );
    }
}
