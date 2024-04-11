// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import "@openzeppelin/contracts/utils/Address.sol";

/**
 * @title Domain Registry
 * @dev A smart contract for managing the registration and ownership of domains on the Ethereum blockchain.
 * This contract allows users to register domains with a level-based structure similar to DNS, supporting both top-level domains (TLDs) and subdomains.
 * Ownership of domains can be transferred, and registration fees are automatically handled and distributed according to pre-defined rules.
 *
 * Key Features and Functions:
 * 1. Domain Registration:
 *    - Users can register both top-level domains and subdomains.
 *    - Registration of a domain requires a fee, which is configurable by the contract owner.
 * A portion of this fee can be distributed to the owner of the parent domain (if applicable).
 *
 * 2. Domain Ownership and Transfer:
 *    - The contract tracks ownership of domains and allows domain owners to transfer their domains to others.
 *    - Ownership information can be queried using `getDomainOwner`.
 *
 * 3. Fee Management:
 *    - The contract owner can update the registration fee to adjust to market conditions or to modify the business model.
 *    - A percentage of the registration fee for subdomains can be automatically transferred to the parent domain's owner as a form of incentive or revenue sharing.
 *
 * 4. Automatic Fee Distribution:
 *    - When a domain is registered, the registration fee is automatically distributed. For top-level domains, the entire fee is transferred to the contract owner.
 * For subdomains, a portion of the fee is distributed to the parent domain's owner.
 *
 * 5. Upgradeable Contract Design:
 *    - Utilizes OpenZeppelin's upgradeable contract pattern to ensure that the contract can be updated in the future
 *      to add new features or fix potential issues without losing the existing state or domain ownership data.
 *
 * 6. Events for Tracking Activities:
 *    - The contract emits events for domain registration and fee updates, providing transparency and allowing tracking of key activities within the contract.
 *
 * Security Considerations:
 *   - The contract includes checks to prevent common issues such as reentrancy attacks during the transfer of funds.
 *   - Access control is implemented using OpenZeppelin's `OwnableUpgradeable` contract to restrict sensitive operations to the contract owner.
 *
 * Note:
 *   - This contract is designed to be upgradeable, ensuring longevity and adaptability of the domain registry system on the Ethereum blockchain.
 *   - Feedback and contributions from the community are welcome to enhance the contract's capabilities and security.
 */

contract V2 is Initializable, OwnableUpgradeable {
    // ____________________ Constants ____________________
    /// @dev Maximum registration fee allowed.
    uint256 public constant MAX_REGISTRATION_FEE = 1 ether;

    /// @dev Percentage of registration fee to be given to domain owner.
    uint256 private constant DOMAIN_OWNER_PERCENTAGE = 20;

    // ____________________ Custom Errors ____________________
    error OnlyOwnerAllowed(string message);
    error IncorrectRegistrationFee(string message);
    error InvalidDomainFormat(string message);
    error DomainAlreadyRegistered(string message);
    error TransferFailed(string message);
    error FeeCannotBeNegativeOrZero(string message);
    error FeeExceedsMaximumAllowed(string message);
    error StartIndexMustBeLessThanEndIndex(string message);
    error EndIndexExceedsTotalDomains(string message);
    error NewOwnerIsZeroAddress(string message);
    error NoFundsForWithdrawal(string message);

    // ____________________ State variables ____________________
    /// @notice Owner of the contract
    address public contractOwner;

    /// @notice Registration fee required to register a domain
    uint256 public registrationFee;

    /// @notice Total number of domains registered in the contract
    uint256 public totalDomainsRegisteredNumber;

    /// @dev Array to store the names of all registered domains
    string[] private registeredDomainNames;

    // ____________________ Data mappings ____________________
    /// @dev Maps domain names to the addresses of their respective owners.
    mapping(string => address) private domains;

    // ____________________ Events ____________________
    /**
     * @dev Emitted when a domain is successfully registered.
     * @param domainName Name of the registered domain.
     * @param owner Address of the domain's owner.
     */
    event DomainRegistered(string domainName, address indexed owner);

    /**
     * @dev Emitted when the registration fee is updated.
     * @param newFee The new registration fee.
     */
    event FeeUpdated(uint256 newFee);

    // ____________________ Initializer ____________________
    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     * This initializer sets up the Ownable contract with the deployer's address
     * and initializes the registration fee to 0.01 ether.
     */

    function initializeV2() public initializer {
        __Ownable_init(msg.sender);
        registrationFee = 0.01 ether;
    }

    // ========================== Functions ==========================

    // ____________________ Core Business Logic Functions ____________________
    /**
     * @notice Registers a new domain.
     * @dev Registers a domain if it is valid and not already registered. Charges a fee and transfers it to the owner.
     * This function does not return a value but emits a DomainRegistered event upon successful domain registration.
     * @param domainName The domain name to register.
     */
    function registerDomain(string memory domainName) external payable {
        if (!isValidDomain(domainName))
            revert InvalidDomainFormat("Invalid domain format");
        if (domains[domainName] != address(0))
            revert DomainAlreadyRegistered("Domain is already registered");
        if (msg.value < registrationFee)
            revert IncorrectRegistrationFee("Incorrect registration fee");

        string[] memory parts = splitDomain(domainName);
        uint256 domainLevel = parts.length;
        address payable ownerAddress = payable(msg.sender);
        address payable parentDomainOwner = payable(address(0));

        // Регистрация домена и обновление состояния контракта
        domains[domainName] = ownerAddress;
        registeredDomainNames.push(domainName);
        totalDomainsRegisteredNumber++;

        if (domainLevel == 1) {
            // Для домена первого уровня весь платеж переводится владельцу контракта
            (bool sent, ) = contractOwner.call{value: msg.value}("");
            require(sent, "Failed to send Ether");
        } else {
            // Для доменов второго уровня и выше определяем владельца родительского домена
            string memory parentDomain = parentDomainName(domainName);
            parentDomainOwner = payable(domains[parentDomain]);
            if (parentDomainOwner == address(0))
                revert InvalidDomainFormat("Parent domain not registered");

            // Расчет и перевод средств
            uint256 parentPayment = (msg.value * DOMAIN_OWNER_PERCENTAGE) / 100;
            uint256 ownerPayment = msg.value - parentPayment;

            // 20% владельцу родительского домена
            (bool parentSent, ) = parentDomainOwner.call{value: parentPayment}(
                ""
            );
            require(parentSent, "Failed to send Ether to parent domain owner");

            // 80% владельцу контракта
            (bool ownerSent, ) = contractOwner.call{value: ownerPayment}("");
            require(ownerSent, "Failed to send Ether to contract owner");
        }
        // Генерация события после успешной регистрации домена
        emit DomainRegistered(domainName, ownerAddress);
    }

    // ____________________ Contract Management Functions ____________________
    /**
     * @dev Updates the domain registration fee to a new value. This function can only be invoked by the owner of the contract.
     * It allows the owner to adjust the fee required for new domain registrations. The fee must be a non-negative value and
     * should not exceed the maximum allowed limit defined by `MAX_REGISTRATION_FEE`, ensuring that the fee remains within
     * reasonable bounds. The updated fee is specified in Wei. Emits a `FeeUpdated` event upon successful update.
     * Requirements:
     * - The caller must be the contract owner.
     * - `newFee` must be greater than or equal to 0.
     * - `newFee` must not exceed `MAX_REGISTRATION_FEE`.
     * @param newFee The new registration fee in Wei. Must be non-negative and not exceed the maximum allowed fee.
     */
    function updateRegistrationFee(uint256 newFee) external onlyOwner {
        if (newFee <= 0)
            revert FeeCannotBeNegativeOrZero("Fee cannot be negative or zero");
        if (newFee > MAX_REGISTRATION_FEE)
            revert FeeExceedsMaximumAllowed(
                "Fee exceeds the maximum allowed limit"
            );

        registrationFee = newFee;
        emit FeeUpdated(newFee);
    }

    // ____________________ View Functions ____________________
    /**
     * @notice Retrieves the owner of a specific domain.
     * @param domainName The name of the domain to query.
     * @return The address of the domain owner.
     */
    function getDomainOwner(
        string memory domainName
    ) public view returns (address) {
        return domains[domainName];
    }

    /**
     * @notice Retrieves a subset of registered domain names between specified indices.
     * @dev This function implements pagination by allowing callers to specify a range of indices.
     * It helps manage large sets of domain names by fetching them in smaller, manageable batches.
     * @param startIndex The index to start fetching domain names from (inclusive).
     * @param endIndex The index to stop fetching domain names (exclusive).
     * @return domainNames A string array containing the domain names within the specified range.
     */
    function getDomainNamesByIndex(
        uint256 startIndex,
        uint256 endIndex
    ) public view returns (string[] memory domainNames) {
        if (startIndex >= endIndex)
            revert StartIndexMustBeLessThanEndIndex(
                "Start index must be less than the end index"
            );
        if (endIndex > registeredDomainNames.length)
            revert EndIndexExceedsTotalDomains(
                "End index exceeds the total number of domains"
            );

        uint256 count = endIndex - startIndex; // Calculate the number of domain names to be returned.
        domainNames = new string[](count); // Initialize the array to hold the domain names.

        for (uint256 i = startIndex; i < endIndex; ++i) {
            domainNames[i - startIndex] = registeredDomainNames[i]; // Populate the array with domain names.
        }

        return domainNames; // Return the populated array of domain names.
    }

    // ============================ Internal Functions ==========================

    // ____________________ Internal Functions: Domain Handling ____________________
    /**
     * @notice Validates a domain based on basic RFC 1035 rules using inline assembly for character iteration and checks.
     * @dev This is a basic check. Some other rules from RFC 1035 may not be enforced.
     * @param domainName The domain name to validate.
     * @return Whether the domain is valid.
     */
    function isValidDomain(
        string memory domainName
    ) internal pure returns (bool) {
        bytes memory domainBytes = bytes(domainName);
        uint256 len = domainBytes.length;

        // Check the domain length to ensure it falls within the allowed range
        if (len < 1 || len > 63) {
            return false;
        }

        bool isValid = true;
        uint8 hyphenCount = 0;

        assembly {
            let dataStart := add(domainBytes, 0x20) // Start of the domain data
            let dataEnd := add(dataStart, len) // End of the domain data

            // Check if the domain starts or ends with a hyphen ('-')
            if or(
                eq(byte(0, mload(dataStart)), 0x2D),
                eq(byte(0, mload(sub(dataEnd, 1))), 0x2D)
            ) {
                isValid := 0
            }

            let prevChar := 0x00 // Previous character, used for checking consecutive characters

            for {

            } and(isValid, lt(dataStart, dataEnd)) {
                // Loop through each character
                dataStart := add(dataStart, 1)
            } {
                let char := byte(0, mload(dataStart)) // Current character

                // Increment hyphen count if a hyphen is found
                if eq(char, 0x2D) {
                    hyphenCount := add(hyphenCount, 1)
                    // Invalidate if more than one consecutive hyphen
                    if gt(hyphenCount, 1) {
                        isValid := 0
                    }
                }

                // Reset hyphen count if a dot is found
                if eq(char, 0x2E) {
                    hyphenCount := 0
                }

                // Check if character is a valid number or letter and reset hyphen count
                if or(
                    or(
                        and(iszero(lt(char, 0x30)), iszero(gt(char, 0x39))), // Numbers 0-9
                        and(iszero(lt(char, 0x61)), iszero(gt(char, 0x7A))) // Lowercase a-z
                    ),
                    and(iszero(lt(char, 0x41)), iszero(gt(char, 0x5A))) // Uppercase A-Z
                ) {
                    hyphenCount := 0
                }

                if and(
                    and(iszero(eq(char, 0x2E)), iszero(eq(char, 0x2D))),
                    and(
                        and(
                            or(lt(char, 0x30), gt(char, 0x39)),
                            or(lt(char, 0x61), gt(char, 0x7A))
                        ),
                        or(lt(char, 0x41), gt(char, 0x5A))
                    )
                ) {
                    // Invalidate if character is not a dot, hyphen, number, or letter
                    isValid := 0
                }
            }
        }

        return isValid;
    }

    /**
     * @notice Splits a domain name string into its constituent parts using inline assembly for character iteration.
     * @dev The function makes two passes through the domain string: counting dots and extracting parts.
     * @param domainName The complete domain name string to be parsed and split.
     * @return parts An array containing individual parts of the domain name split by dots.
     */
    function splitDomain(
        string memory domainName
    ) internal pure returns (string[] memory) {
        uint length = bytes(domainName).length;
        uint count = 1; // At least one domain part

        // First pass: count dots
        for (uint i = 0; i < length; i++) {
            bytes1 char;
            assembly {
                char := mload(add(add(domainName, 0x20), i))
            }
            if (char == ".") {
                count++;
            }
        }

        string[] memory parts = new string[](count);
        uint startIndex = 0;
        uint arrayIndex = 0;

        // Second pass: extract parts
        for (uint i = 0; i < length; i++) {
            bytes1 char;
            assembly {
                char := mload(add(add(domainName, 0x20), i))
            }
            if (char == "." || i == length - 1) {
                uint endIndex = char == "." ? i : i + 1;
                bytes memory part = new bytes(endIndex - startIndex);
                for (uint j = 0; j < part.length; j++) {
                    assembly {
                        mstore(
                            add(add(part, 0x20), j),
                            mload(
                                add(add(domainName, 0x20), add(startIndex, j))
                            )
                        )
                    }
                }
                parts[arrayIndex] = string(part);
                arrayIndex++;
                startIndex = i + 1;
            }
        }

        return parts;
    }

    /**
     * @notice Retrieves the parent domain name of a given domain.
     * @dev Splits the domain name into its constituent parts and constructs the parent domain name.
     * If the domain name has multiple parts, it constructs the parent domain name by removing the first part.
     * For example, if the input domain is "sub.domain.com", the parent domain would be "domain.com".
     * @param domainName The domain name for which the parent domain is to be retrieved.
     * @return The parent domain name.
     */
    function parentDomainName(
        string memory domainName
    ) internal pure returns (string memory) {
        // Split the domain name into its constituent parts
        string[] memory parts = splitDomain(domainName);
        // Initialize the result as an empty string
        string memory result = "";
        // Check if the domain has multiple parts
        if (parts.length > 1) {
            // Iterate through each part of the domain name
            for (uint i = 1; i < parts.length; i++) {
                // If it's not the first part, append a dot to separate parts
                if (i != 1) {
                    result = string(abi.encodePacked(result, "."));
                }
                // Append the current part to the result
                result = string(abi.encodePacked(result, parts[i]));
            }
        }
        // Return the constructed parent domain name
        return result;
    }

    // ____________________ Internal Functions: Utility ____________________
    /**
     * @notice Efficiently slices a bytes array from the given start position for the specified length using inline assembly.
     * @param data The original bytes array.
     * @param start The starting position for the slice.
     * @param len The length of the slice.
     * @return The resulting bytes array slice.
     */
    function slice(
        bytes memory data,
        uint start,
        uint len
    ) internal pure returns (bytes memory) {
        bytes memory result = new bytes(len);

        assembly {
            // Указатель на начало данных в исходном массиве
            let data_ptr := add(add(data, 0x20), start)

            // Указатель на начало данных в результирующем массиве
            let result_ptr := add(result, 0x20)

            // Копирование среза данных
            for {
                let end_ptr := add(data_ptr, len)
            } lt(data_ptr, end_ptr) {
                data_ptr := add(data_ptr, 0x20)
                result_ptr := add(result_ptr, 0x20)
            } {
                mstore(result_ptr, mload(data_ptr))
            }
        }

        return result;
    }
}
