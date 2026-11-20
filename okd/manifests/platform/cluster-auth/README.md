# AzureAD and az-cli Commands

```bash
# View jwt token
export TOKEN=$(az account get-access-token --query accessToken -o tsv)
echo $TOKEN | jwt decode -

# View OIDC config and supported claims
export TENANT_ID=""
curl -s https://login.microsoftonline.com/${TENANT_ID}/v2.0/.well-known/openid-configuration
```
