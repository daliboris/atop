<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:xs="http://www.w3.org/2001/XMLSchema"
  xmlns:xd="http://www.oxygenxml.com/ns/doc/xsl"
  xmlns="http://www.tei-c.org/ns/1.0"
  xmlns:tei="http://www.tei-c.org/ns/1.0"
  xmlns:atop="http://www.tei-c.org/ns/atop"
  xpath-default-namespace="http://www.tei-c.org/ns/1.0"
  exclude-result-prefixes="#all"
  version="3.0">
  
  <xd:doc>
    <xd:desc>Version number of this program</xd:desc>
  </xd:doc>
  <xsl:variable name="atop:vVersion" select="'0.0.4'" as="xs:string"/>
  
  <xd:doc scope="stylesheet">
    <xd:desc>
      <xd:p><xd:b>Created:</xd:b> 2024-08-22.</xd:p>
      <xd:p><xd:b>Author:</xd:b> ATOP task force</xd:p>
      <xd:p>Routine to read in an ODD (whether a customization ODD or
      a base ODD, although will likely not have much work to do on the
      latter) and writes out the same with external references
      resolved.</xd:p>
    </xd:desc>
  </xd:doc>
  
  <xd:doc>
    <xd:desc>We use the global functions module.</xd:desc>
  </xd:doc>
  <xsl:include href="modules/functions_module.xslt"/>
  
  <xsl:output method="xml" indent="yes" encoding="UTF-8" normalization-form="NFC"/>
  
  <xd:doc>
    <xd:desc>Default processing is to copy myself and continue processing …</xd:desc>
  </xd:doc>
  <xsl:mode on-no-match="shallow-copy"/>
  
  <xd:doc>
    <xd:desc>Expand module references that point to external
      schemas. The use of the value <val>.</val> for
      <att>url</att> is not strictly necessary, but ATOP uses it to
      signify that the content is here and now, and no longer
      external.</xd:desc>
  </xd:doc>
  <xsl:template match="moduleRef[@url[not(. eq '.')]]" as="element(moduleRef)">
    <xsl:copy>
      <xsl:apply-templates select="@*"/>
      <!-- Use a value of ‘.’ (U+002E) on @url to signify that the content is here and now, not external. -->
      <xsl:attribute name="url" select="'.'"/>
      <content>
        <xsl:apply-templates select="content/@*"/>
        <xsl:apply-templates select="content/*"/>
        <xsl:if test="doc-available( @url )">
          <xsl:comment select="'========= from '||normalize-space(@url)||' ========='"/>
          <xsl:copy-of select="doc(@url)"/>
        </xsl:if>
      </content>
    </xsl:copy>
  </xsl:template>

  <xd:doc>
    <xd:desc>If we find a <gi>dataRef</gi> with a <att>ref</att>
    attribute, we have no idea how to process it, so just warn the
    user that we are not going to.</xd:desc>
  </xd:doc>
  <xsl:template match="dataRef[ @ref ]" as="item()*">
    <xsl:message terminate="no" expand-text="true">WARNING: The ATOP
    processor does not know how to handle a reference to the {@ref}
    external datatype library, so this dataRef element is being
    summarily ignored.</xsl:message>
  </xsl:template>

  <xd:doc>
    <xd:desc>A <gi>specGrpRef</gi> gets replaced not with the entire
    <gi>specGrp</gi> to which it refers, but rather only with the
    output of processing the <emph>contents</emph> of the <gi>specGrp</gi>
    to which it refers.</xd:desc>
  </xd:doc>
  <xsl:template match="specGrpRef" as="element()*">
    <!-- Get the target (it should point to a <specGrp>) -->
    <xsl:variable name="vTargetVal" select="normalize-space(@target)" as="xs:string"/>
    <!-- Get the <sepcGrp> to which it points -->
    <xsl:variable name="vTargetSpecGrp" as="element(specGrp)">
      <xsl:choose>
        <!--
          If it starts with a ‘#’, it should be just a bare name fragment identifier
          (at least, that is the only kind of fragment identifier we know how to
          process). Retrieve the <specGrp> in this document that it points to.
        -->
        <xsl:when test="starts-with( $vTargetVal, '#')">
          <xsl:sequence select="id( substring( $vTargetVal, 2 ) )"/>
        </xsl:when>
        <!--
          If it contains a ‘#’, grab the document referred to first, then the
          <specGrp> within that document.
        -->
        <xsl:when test="contains( $vTargetVal, '#')">
          <xsl:variable name="vTargetUriPart" select="substring-before( $vTargetVal, '#')" as="xs:string"/>
          <xsl:variable name="vTargetFragment" select="substring-after( $vTargetVal, '#')" as="xs:string"/>
          <xsl:variable name="vTargetDoc" select="document( atop:resolve-uri( $vTargetUriPart cast as xs:anyURI, / ) )" as="document-node()"/>
          <xsl:sequence select="id( $vTargetFragment, $vTargetDoc )"/>
        </xsl:when>
        <!--
          If it does not contain a ‘#’, then it points to an entire document. Must be
          that the outermost element of that document is a <specGrp>, so return it.
        -->
        <xsl:otherwise>
          <xsl:sequence select="document( atop:resolve-uri( $vTargetVal cast as xs:anyURI, () ) )/specGrp"/>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <xsl:apply-templates select="$vTargetSpecGrp/*"/>
  </xsl:template>

  <xd:doc>
    <xd:desc>A <gi>specGrp</gi> that is pointed to by a
    <gi>specGrpRef</gi> gets ignored (as it is processed
    when &amp; where the <gi>specGrpRef</gi> occurs).</xd:desc>
  </xd:doc>
  <xsl:template match="specGrp[ //specGrpRef[ @target => normalize-space() => substring(2) eq current()/@xml:id ] ]"/>

  <xd:doc>
    <xd:desc>QUESTION: What happens to a <gi>specGrp</gi> that is
    <emph>not</emph> referred to by a <gi>specGrpRef</gi>?</xd:desc>
  </xd:doc>
  <xsl:template match="specGrp">
    <!-- Only matches those that are NOT pointed at by a local <specGrpRef>,
	 as previous template catches those at a higher priority. -->
    <xsl:message>DEBUG: WTF? :GUBED</xsl:message>
  </xsl:template>
  
  <xd:doc>
    <xd:desc>When we read in a <gi>*Ref</gi> that points to a TEI ODD
    specification in an external source (i.e., has a @key), replace it
    with the corresponding <gi>*Spec</gi>s from that source.</xd:desc>
  </xd:doc>
  <!-- moduleRef/@url and dataRef/@ref are handled above; we do not
       need to process dataRef/@name here, as it does not point to
       anything external and will be processed by transpilation. -->
  <xsl:template match="( classRef | dataRef | elementRef | macroRef | moduleRef )
                       [ parent::schemaSpec | parent::specGrp ]
                       [ @key  and  @source ]" as="node()">
    <xsl:variable name="vKey" select="normalize-space(@key)" as="xs:string"/>
    <xsl:variable name="vSource" select="normalize-space(@source)" as="xs:string"/>
    <xsl:variable name="vSpecName" select="replace( local-name(.), 'Ref$','Spec') => xs:NCName()" as="xs:NCName"/>
    <xsl:variable name="vSourceDoc" select="document( atop:resolve-uri( $vSource cast as xs:anyURI, () ) )" as="document-node()"/>
    <xsl:message select="'debug: I seek '||$vSpecName||'[ @ident eq '||$vKey||' ] in '||atop:resolve-uri( $vSource cast as xs:anyURI, () )"/>
    <xsl:variable name="vSpecToGrab" as="element()*">
      <xsl:evaluate context-item="$vSourceDoc" xpath="'//'||$vSpecName||'[ @ident eq &quot;'||$vKey||'&quot; ]'"/>
    </xsl:variable>
    <xsl:message select="'debug: I have '
      ||count($vSpecToGrab)
      ||' to slurp in, name(s): '
      ||$vSpecToGrab!name() => string-join(', ')"/>
    <xsl:apply-templates select="$vSpecToGrab" mode="atop:replacement"/>
  </xsl:template>

  <xd:doc>
    <xd:desc>process the <gi>*Spec</gi> from source (as opposed to the input).
    At the moment, proccessing is just copying it over, except that the @mode
    of the outermost element copied from the source is set to "replace".</xd:desc>
  </xd:doc>
  <xsl:template match="*" mode="atop:replacement" as="element()">
    <xsl:copy>
      <xsl:apply-templates select="@*" mode="#default"/>
      <xsl:if test="@mode eq 'add' or not( @mode )">
        <xsl:attribute name="mode" select="'replace'"/>
      </xsl:if>
      <xsl:apply-templates select="node()" mode="#default"/>
    </xsl:copy>
  </xsl:template>
  
</xsl:stylesheet>
