package social.betty.features.profile

import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.browser.customtabs.CustomTabsIntent
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Text
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.dp
import androidx.core.net.toUri
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import social.betty.core.model.Country
import social.betty.core.net.ApiError
import social.betty.designsystem.BettyTheme
import social.betty.designsystem.Palette
import social.betty.designsystem.Radius
import social.betty.designsystem.Space
import social.betty.designsystem.ThemeMode
import social.betty.designsystem.components.Avatar
import social.betty.designsystem.components.AvatarSize
import social.betty.designsystem.components.BettyButton
import social.betty.designsystem.components.BettyButtonVariant
import social.betty.designsystem.components.BettyScaffold
import social.betty.designsystem.components.InsetPanel
import social.betty.designsystem.components.KickerText
import social.betty.designsystem.components.SurfaceCard
import social.betty.navigation.LocalAppContainer
import social.betty.navigation.LocalAppState
import social.betty.navigation.LocalNavigator
import social.betty.navigation.Route

/**
 * Web HeaderBar dropdown + `UpdateProfileModal` as a full tab screen: avatar with the
 * presigned photo upload, name + country edit (PUT /user/me applies ONLY those two —
 * email is never sent), appearance toggle, links, and sign out.
 */
@Composable
fun ProfileScreen() {
    val container = LocalAppContainer.current
    val appState = LocalAppState.current
    val nav = LocalNavigator.current
    val scope = rememberCoroutineScope()
    val context = LocalContext.current
    val colors = BettyTheme.colors
    val type = BettyTheme.type

    val user by container.userStore.user.collectAsStateWithLifecycle()
    val countries by container.countries.countries.collectAsStateWithLifecycle()

    var name by remember { mutableStateOf("") }
    var country by remember { mutableStateOf<String?>(null) }
    var isSaving by remember { mutableStateOf(false) }
    var hasPrefilled by remember { mutableStateOf(false) }

    var isUploadingImage by remember { mutableStateOf(false) }
    var imageError by remember { mutableStateOf<String?>(null) }

    // Prefill from the loaded profile once; load countries on first appearance.
    LaunchedEffect(Unit) {
        container.countries.load()
        if (!hasPrefilled) {
            container.userStore.user.value?.let { profile ->
                name = profile.name
                country = profile.country?.takeIf { it.isNotEmpty() }
            }
            hasPrefilled = true
        }
    }

    val photoPicker = rememberLauncherForActivityResult(
        ActivityResultContracts.PickVisualMedia(),
    ) { uri ->
        if (uri == null || isUploadingImage) return@rememberLauncherForActivityResult
        imageError = null
        isUploadingImage = true
        scope.launch {
            try {
                val bytes = withContext(Dispatchers.IO) {
                    context.contentResolver.openInputStream(uri)?.use { it.readBytes() }
                }
                if (bytes == null) {
                    imageError = ProfileImagePolicy.GENERIC_UPLOAD_MESSAGE
                    return@launch
                }
                val contentType = ProfileImagePolicy.sniffContentType(bytes)
                    ?: context.contentResolver.getType(uri)
                    ?: "application/octet-stream"
                val validation = ProfileImagePolicy.validationError(contentType, bytes.size)
                if (validation != null) {
                    imageError = validation
                    return@launch
                }
                val presigned = container.api.profileImageUploadUrl(contentType, bytes.size.toLong())
                val status = container.api.client.rawUpload(
                    url = presigned.uploadUrl,
                    method = presigned.method,
                    headers = presigned.headers,
                    contentType = contentType,
                    bytes = bytes,
                )
                if (status !in 200..299) {
                    imageError = ProfileImagePolicy.uploadErrorMessage(status)
                    return@launch
                }
                val publicUrl = container.api.commitProfileImage(presigned.publicUrl)
                container.userStore.patchImage(publicUrl)
            } catch (e: ApiError.Status) {
                imageError = ProfileImagePolicy.uploadErrorMessage(e.code)
            } catch (e: Exception) {
                imageError = ProfileImagePolicy.GENERIC_UPLOAD_MESSAGE
            } finally {
                isUploadingImage = false
            }
        }
    }

    fun revertImage() {
        if (isUploadingImage) return
        imageError = null
        isUploadingImage = true
        scope.launch {
            try {
                val reverted = container.api.deleteProfileImage()
                container.userStore.patchImage(reverted)
            } catch (e: Exception) {
                imageError = ProfileImagePolicy.REVERT_FAILED_MESSAGE
            } finally {
                isUploadingImage = false
            }
        }
    }

    fun save() {
        if (name.isEmpty() || isSaving) return
        isSaving = true
        scope.launch {
            try {
                // PUT /user/me only applies name + country — never send email.
                val updated = container.api.updateUserMe(name, country)
                container.userStore.set(updated)
                container.notify.success("All saved — looking sharp.")
            } catch (e: Exception) {
                container.notify.critical("Your profile could not be updated, please try again.")
            } finally {
                isSaving = false
            }
        }
    }

    BettyScaffold(modifier = Modifier.testTag("profile-screen")) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(Space.m)
                .padding(bottom = Space.xxl),
            verticalArrangement = Arrangement.spacedBy(Space.m),
        ) {
            KickerText(text = "★ ACCOUNT", color = Palette.orange)
            Text(
                text = "EDIT PROFILE",
                style = type.displayL,
                color = colors.textPrimary,
            )

            AvatarSection(
                name = name,
                profileName = user?.name,
                profileEmail = user?.email,
                imageUrl = user?.imageUrl,
                showRevert = ProfileImagePolicy.hasCustomImage(user?.imageUrl, user?.firebaseImageUrl),
                isUploading = isUploadingImage,
                onPickPhoto = {
                    photoPicker.launch(
                        PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly),
                    )
                },
                onRevert = ::revertImage,
            )

            imageError?.let { message ->
                InsetPanel(accent = Palette.orange) {
                    Text(
                        text = message,
                        style = type.subhead,
                        color = colors.textPrimary,
                        modifier = Modifier.fillMaxWidth(),
                    )
                }
            }

            FormCard(
                name = name,
                onNameChange = { name = it },
                country = country,
                countries = countries,
                onCountryChange = { country = it },
                themeMode = container.themeStore.mode,
                onThemeChange = { container.themeStore.set(it) },
                isSaving = isSaving,
                onSave = ::save,
            )

            LinksCard(
                isAdmin = container.userStore.isAdmin,
                onSupport = { nav.push(Route.Support) },
                onAbout = { nav.push(Route.About) },
                onPrivacy = {
                    runCatching {
                        CustomTabsIntent.Builder().build()
                            .launchUrl(context, "https://betty.social/privacy".toUri())
                    }
                },
                onAdmin = { nav.push(Route.AdminEvaluate) },
            )

            BettyButton(
                text = "SIGN OUT",
                onClick = { appState.signOut(scope) },
                modifier = Modifier.testTag("profile-signout"),
                variant = BettyButtonVariant.DESTRUCTIVE,
                block = true,
            )
        }
    }
}

@Composable
private fun AvatarSection(
    name: String,
    profileName: String?,
    profileEmail: String?,
    imageUrl: String?,
    showRevert: Boolean,
    isUploading: Boolean,
    onPickPhoto: () -> Unit,
    onRevert: () -> Unit,
) {
    val colors = BettyTheme.colors
    val type = BettyTheme.type

    Column(
        modifier = Modifier.fillMaxWidth(),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(Space.s),
    ) {
        Box(
            contentAlignment = Alignment.Center,
            modifier = Modifier
                .size(AvatarSize.large)
                .clip(CircleShape)
                .clickable(enabled = !isUploading, onClick = onPickPhoto),
        ) {
            Avatar(
                url = imageUrl,
                name = name.ifEmpty { profileName },
                size = AvatarSize.large,
            )
            if (isUploading) {
                Box(
                    contentAlignment = Alignment.Center,
                    modifier = Modifier
                        .size(AvatarSize.large)
                        .clip(CircleShape)
                        .background(Palette.modalBackdrop),
                ) {
                    CircularProgressIndicator(color = Color.White, strokeWidth = 2.dp)
                }
            } else {
                Box(modifier = Modifier.align(Alignment.BottomCenter)) {
                    Text(
                        text = "CHANGE",
                        style = type.kicker,
                        color = Color.White,
                        modifier = Modifier
                            .clip(Radius.sharp)
                            .background(Palette.pillDark)
                            .padding(vertical = 3.dp, horizontal = 7.dp),
                    )
                }
            }
        }

        Text(
            text = profileName.orEmpty(),
            style = type.headline,
            color = colors.textPrimary,
            modifier = Modifier.testTag("profile-name"),
        )
        Text(
            text = profileEmail.orEmpty(),
            style = type.subhead,
            color = colors.textSecondary,
            modifier = Modifier.testTag("profile-email"),
        )

        if (showRevert) {
            BettyButton(
                text = "REVERT TO PROVIDER PHOTO",
                onClick = onRevert,
                variant = BettyButtonVariant.GHOST,
                enabled = !isUploading,
            )
        }
    }
}

@Composable
private fun FormCard(
    name: String,
    onNameChange: (String) -> Unit,
    country: String?,
    countries: List<Country>,
    onCountryChange: (String?) -> Unit,
    themeMode: ThemeMode,
    onThemeChange: (ThemeMode) -> Unit,
    isSaving: Boolean,
    onSave: () -> Unit,
) {
    val colors = BettyTheme.colors
    val type = BettyTheme.type

    SurfaceCard {
        Column(verticalArrangement = Arrangement.spacedBy(Space.m)) {
            Column(verticalArrangement = Arrangement.spacedBy(Space.xs)) {
                KickerText(text = "USER NAME", color = colors.textMuted)
                ProfileTextField(
                    value = name,
                    onValueChange = onNameChange,
                    placeholder = "Betty",
                    singleLine = true,
                    modifier = Modifier.testTag("profile-edit-name"),
                )
            }

            Column(verticalArrangement = Arrangement.spacedBy(Space.xs)) {
                KickerText(text = "COUNTRY", color = colors.textMuted)
                CountryPicker(
                    country = country,
                    countries = countries,
                    onCountryChange = onCountryChange,
                )
            }

            Column(verticalArrangement = Arrangement.spacedBy(Space.xs)) {
                KickerText(text = "APPEARANCE", color = colors.textMuted)
                AppearancePicker(themeMode = themeMode, onThemeChange = onThemeChange)
            }

            BettyButton(
                text = if (isSaving) "SAVING…" else "SAVE PROFILE",
                onClick = onSave,
                modifier = Modifier.testTag("profile-save"),
                enabled = !isSaving && name.isNotEmpty(),
                loading = isSaving,
                block = true,
            )
        }
    }
}

@Composable
private fun CountryPicker(
    country: String?,
    countries: List<Country>,
    onCountryChange: (String?) -> Unit,
) {
    val colors = BettyTheme.colors
    val type = BettyTheme.type
    var expanded by remember { mutableStateOf(false) }

    val selected = countries.firstOrNull { it.code.equals(country, ignoreCase = true) }
    val label = selected?.let { countryLabel(it) } ?: "— Not set —"

    Box(modifier = Modifier.fillMaxWidth()) {
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .clip(Radius.sharp)
                .background(colors.overlay06)
                .clickable { expanded = true }
                .padding(Space.s)
                .testTag("profile-country"),
        ) {
            Text(text = label, style = type.body, color = colors.textPrimary)
        }
        DropdownMenu(
            expanded = expanded,
            onDismissRequest = { expanded = false },
        ) {
            DropdownMenuItem(
                text = { Text("— Not set —") },
                onClick = {
                    onCountryChange(null)
                    expanded = false
                },
            )
            countries.forEach { item ->
                DropdownMenuItem(
                    text = { Text(countryLabel(item)) },
                    onClick = {
                        onCountryChange(item.code)
                        expanded = false
                    },
                )
            }
        }
    }
}

private fun countryLabel(country: Country): String {
    val flag = country.flagEmoji
    return if (!flag.isNullOrEmpty()) "$flag  ${country.name}" else country.name
}

@Composable
private fun AppearancePicker(
    themeMode: ThemeMode,
    onThemeChange: (ThemeMode) -> Unit,
) {
    val colors = BettyTheme.colors
    val type = BettyTheme.type

    val options = listOf(
        Triple("SYSTEM", ThemeMode.SYSTEM, "profile-appearance-system"),
        Triple("LIGHT", ThemeMode.LIGHT, "profile-appearance-light"),
        Triple("DARK", ThemeMode.DARK, "profile-appearance-dark"),
    )

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(Radius.sharp)
            .background(colors.overlay04)
            .padding(3.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        options.forEach { (label, mode, tag) ->
            val isActive = themeMode == mode
            Box(
                contentAlignment = Alignment.Center,
                modifier = Modifier
                    .weight(1f)
                    .clip(Radius.sharp)
                    .background(if (isActive) Palette.orangeTint18 else Color.Transparent)
                    .clickable { onThemeChange(mode) }
                    .padding(vertical = 8.dp)
                    .testTag(tag),
            ) {
                Text(
                    text = label,
                    style = type.kicker,
                    color = if (isActive) Palette.orange else colors.textMuted,
                )
            }
        }
    }
}

@Composable
private fun LinksCard(
    isAdmin: Boolean,
    onSupport: () -> Unit,
    onAbout: () -> Unit,
    onPrivacy: () -> Unit,
    onAdmin: () -> Unit,
) {
    SurfaceCard {
        Column(verticalArrangement = Arrangement.spacedBy(Space.s)) {
            LinkRow(title = "Support", onClick = onSupport, modifier = Modifier.testTag("profile-support"))
            LinkRow(title = "About", onClick = onAbout, modifier = Modifier.testTag("profile-about"))
            LinkRow(title = "Privacy", onClick = onPrivacy)
            if (isAdmin) {
                LinkRow(title = "Admin", onClick = onAdmin, modifier = Modifier.testTag("profile-admin"))
            }
        }
    }
}

@Composable
private fun LinkRow(
    title: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val colors = BettyTheme.colors
    val type = BettyTheme.type
    Row(
        modifier = modifier
            .fillMaxWidth()
            .clickable(onClick = onClick)
            .padding(vertical = Space.xs),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(text = title, style = type.body, color = colors.textPrimary)
        Spacer(Modifier.weight(1f))
        Text(text = "›", style = type.headline, color = colors.textSecondary)
    }
}

@Composable
private fun ProfileTextField(
    value: String,
    onValueChange: (String) -> Unit,
    placeholder: String,
    modifier: Modifier = Modifier,
    singleLine: Boolean = true,
) {
    val colors = BettyTheme.colors
    OutlinedTextField(
        value = value,
        onValueChange = onValueChange,
        placeholder = {
            Text(text = placeholder, style = BettyTheme.type.body, color = colors.textMuted)
        },
        singleLine = singleLine,
        colors = OutlinedTextFieldDefaults.colors(
            focusedContainerColor = colors.overlay06,
            unfocusedContainerColor = colors.overlay06,
            focusedTextColor = colors.textPrimary,
            unfocusedTextColor = colors.textPrimary,
            focusedBorderColor = Palette.orange,
            unfocusedBorderColor = colors.overlay10,
            cursorColor = colors.textPrimary,
        ),
        shape = Radius.sharp,
        modifier = modifier.fillMaxWidth(),
    )
}
