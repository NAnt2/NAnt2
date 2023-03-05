<%@ Page Title="Register an external login" Language="C#" MasterPageFile="~/Site.Master" AutoEventWireup="true" CodeBehind="RegisterExternalLogin.aspx.cs" Inherits="WebApplication.Account.RegisterExternalLogin" Async="true" %>

<asp:Content runat="server" ID="BodyContent" ContentPlaceHolderID="MainContent">
    <main>
        <h3>Register with your <%: ProviderName %> account</h3>
        <asp:PlaceHolder runat="server">
            <h4>Association Form</h4>
            <hr />
            <asp:ValidationSummary runat="server" ShowModelStateErrors="true" CssClass="text-danger" />
            <p class="text-info">
                You've authenticated with <strong><%: ProviderName %></strong>. Please enter an email below for the current site
                and click the Log in button.
            </p>

            <div class="row">
                <asp:Label runat="server" AssociatedControlID="email" CssClass="col-md-2 col-form-label">Email</asp:Label>
                <div class="col-md-10">
                    <asp:TextBox runat="server" ID="email" CssClass="form-control" TextMode="Email" />
                    <asp:RequiredFieldValidator runat="server" ControlToValidate="email"
                        Display="Dynamic" CssClass="text-danger" ErrorMessage="Email is required" />
                    <asp:ModelErrorMessage runat="server" ModelStateKey="email" CssClass="text-error" />
                </div>
            </div>

            <div class="row">
                <div class="offset-md-2 col-md-10">
                    <asp:Button runat="server" Text="Log in" CssClass="btn btn-outline-dark" OnClick="LogIn_Click" />
                </div>
            </div>
        </asp:PlaceHolder>
    </main>
</asp:Content>
