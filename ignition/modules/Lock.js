const { buildModule } = require("@nomicfoundation/hardhat-ignition/modules");

module.exports = buildModule("platform", (m) => {
  // Set your desired initial token supply (e.g., 1,000,000 tokens)
  const initialSupply = m.getParameter("initialSupply", 1_000_000);

  const platformToken = m.contract("PlatformToken", [initialSupply]);

  return { platformToken };
});
