<!--100011, 100012, 100013-->

<group name="ransomware,">
  <!-- 1. 랜섬웨어 확장자 등장 -->
  <rule id="100011" level="12">
    <decoded_as>syscheck</decoded_as>
    <field name="syscheck.path">\.(encrypted|locked|crypt)$</field>
    <description>Ransomware suspicious file extension detected (encrypted/locked/crypt)</description>
  </rule>

  <!-- 2. 랜섬노트 파일 패턴 -->
  <rule id="100012" level="10">
    <decoded_as>syscheck</decoded_as>
    <field name="syscheck.path">README.txt|HOW_TO_DECRYPT.txt|HELP_RECOVER_FILES.txt</field>
    <description>Possible ransomware note file created</description>
  </rule>

  <!-- 3. 단시간 내 대량 파일 변경 패턴 -->
  <rule id="100013" level="12">
    <if_sid>550</if_sid>
    <frequency>60</frequency>
    <timeframe>60</timeframe>
    <description>possible ransomware activity</description>
    <group>ransomware,</group>
  </rule>
</group>