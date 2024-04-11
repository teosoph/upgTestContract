const { buildModule } = require("@nomicfoundation/hardhat-ignition/modules");

module.exports = buildModule("LockModule", (m) => {
  const V1contract = m.contract("V1", [], {
    gasPrice: 10,
    initializer: "initialize",
  });

  return { V1contract };
});
//
// npx hardhat ignition deploy ignition/modules/V1.js --network localhost
