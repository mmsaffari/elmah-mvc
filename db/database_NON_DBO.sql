/*
	This is a demonstration of how you can put ELMAH tables and procs in a Schema other than [dbo].
	1. Create a Login named [elmah_user]
	2. Create a Schema named [ELMAH] and set it as the default schema for [elmah_user] login on your database
	3. Run this script with a login that CAN CREATE TABLE (most likely a login other than elmah_user who is the [dbo] of your database)
	4. Add a connectionString named "Elmah" to your project in Visual Studio
		<add name="Elmah" connectionString="Server=.;UId=elmah_user;PWd=123456;Database=ELMAH_DB"/>
	5. Make sure the <elmah></elmah> section in Web.Config loks like this:
		<elmah xmlns="http://Elmah.Configuration">
			<security allowRemoteAccess="true"/>
			<errorLog applicationName="Application Name Here" connectionStringName="Elmah" type="Elmah.SqlErrorLog, Elmah"/>
		</elmah>
*/
USE [ELMAH_DB];
GO
/****** Object:  Table [ELMAH].[ELMAH_Error]	Script Date: 03/02/2011 22:37:07 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [ELMAH].[ELMAH_Error](
	[ErrorId] [uniqueidentifier] NOT NULL,
	[Application] [nvarchar](60) NOT NULL,
	[Host] [nvarchar](50) NOT NULL,
	[Type] [nvarchar](100) NOT NULL,
	[Source] [nvarchar](60) NOT NULL,
	[Message] [nvarchar](500) NOT NULL,
	[User] [nvarchar](50) NOT NULL,
	[StatusCode] [int] NOT NULL,
	[TimeUtc] [datetime] NOT NULL,
	[Sequence] [int] IDENTITY(1,1) NOT NULL,
	[AllXml] [ntext] NOT NULL,
 CONSTRAINT [PK_ELMAH_Error] PRIMARY KEY NONCLUSTERED 
(
	[ErrorId] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [IX_ELMAH_Error_App_Time_Seq] ON [ELMAH].[ELMAH_Error] 
(
	[Application] ASC,
	[TimeUtc] DESC,
	[Sequence] DESC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
GO
/****** Object:  StoredProcedure [ELMAH].[ELMAH_LogError]	Script Date: 03/02/2011 22:37:18 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [ELMAH].[ELMAH_LogError]
(
	@ErrorId UNIQUEIDENTIFIER,
	@Application NVARCHAR(60),
	@Host NVARCHAR(30),
	@Type NVARCHAR(100),
	@Source NVARCHAR(60),
	@Message NVARCHAR(500),
	@User NVARCHAR(50),
	@AllXml NTEXT,
	@StatusCode INT,
	@TimeUtc DATETIME
)
AS

	SET NOCOUNT ON

	INSERT
	INTO
		[ELMAH_Error]
		(
			[ErrorId],
			[Application],
			[Host],
			[Type],
			[Source],
			[Message],
			[User],
			[AllXml],
			[StatusCode],
			[TimeUtc]
		)
	VALUES
		(
			@ErrorId,
			@Application,
			@Host,
			@Type,
			@Source,
			@Message,
			@User,
			@AllXml,
			@StatusCode,
			@TimeUtc
		)
GO
/****** Object:  StoredProcedure [ELMAH].[ELMAH_GetErrorXml]	Script Date: 03/02/2011 22:37:18 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [ELMAH].[ELMAH_GetErrorXml]
(
	@Application NVARCHAR(60),
	@ErrorId UNIQUEIDENTIFIER
)
AS

	SET NOCOUNT ON

	SELECT 
		[AllXml]
	FROM 
		[ELMAH_Error]
	WHERE
		[ErrorId] = @ErrorId
	AND
		[Application] = @Application
GO
/****** Object:  StoredProcedure [ELMAH].[ELMAH_GetErrorsXml]	Script Date: 03/02/2011 22:37:18 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [ELMAH].[ELMAH_GetErrorsXml]
(
	@Application NVARCHAR(60),
	@PageIndex INT = 0,
	@PageSize INT = 15,
	@TotalCount INT OUTPUT
)
AS 

	SET NOCOUNT ON

	DECLARE @FirstTimeUTC DATETIME
	DECLARE @FirstSequence INT
	DECLARE @StartRow INT
	DECLARE @StartRowIndex INT

	SELECT 
		@TotalCount = COUNT(1) 
	FROM 
		[ELMAH_Error]
	WHERE 
		[Application] = @Application

	-- Get the ID of the first error for the requested page

	SET @StartRowIndex = @PageIndex * @PageSize + 1

	IF @StartRowIndex <= @TotalCount
	BEGIN

		SET ROWCOUNT @StartRowIndex

		SELECT  
			@FirstTimeUTC = [TimeUtc],
			@FirstSequence = [Sequence]
		FROM 
			[ELMAH_Error]
		WHERE   
			[Application] = @Application
		ORDER BY 
			[TimeUtc] DESC, 
			[Sequence] DESC

	END
	ELSE
	BEGIN

		SET @PageSize = 0

	END

	-- Now set the row count to the requested page size and get
	-- all records below it for the pertaining application.

	SET ROWCOUNT @PageSize

	SELECT 
		errorId	 = [ErrorId], 
		application = [Application],
		host		= [Host], 
		type		= [Type],
		source	  = [Source],
		message	 = [Message],
		[user]	  = [User],
		statusCode  = [StatusCode], 
		time		= CONVERT(VARCHAR(50), [TimeUtc], 126) + 'Z'
	FROM 
		[ELMAH_Error] error
	WHERE
		[Application] = @Application
	AND
		[TimeUtc] <= @FirstTimeUTC
	AND 
		[Sequence] <= @FirstSequence
	ORDER BY
		[TimeUtc] DESC, 
		[Sequence] DESC
	FOR
		XML AUTO
GO
/****** Object:  Default [DF_ELMAH_Error_ErrorId]	Script Date: 03/02/2011 22:37:07 ******/
ALTER TABLE [ELMAH].[ELMAH_Error] ADD  CONSTRAINT [DF_ELMAH_Error_ErrorId]  DEFAULT (newid()) FOR [ErrorId]
GO
