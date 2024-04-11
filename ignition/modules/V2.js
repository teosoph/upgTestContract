const { buildModule } = require("@nomicfoundation/hardhat-ignition/modules");

module.exports = buildModule("LockModule", (m) => {
  // upgraded to V2
  const V2contract = m.contract("V2", [], {
    gasPrice: 10,
    initializer: "initialize",
  });

  return { V2contract };
});
//
// npx hardhat ignition deploy ignition/modules/V2.js --network localhost
